# CrystalPVPJarScanner.ps1
# Scans ONLY the currently running Minecraft instance
# Balanced mode:
#  - Size mismatch flagged only if >15% AND >200 KB difference
#  - Detects known cheat clients via package / mod id
#  - Detects suspicious classes by filename
#  - No keyword scanning inside code (to avoid false positives)

$ErrorActionPreference = "SilentlyContinue"

# Optional Discord webhook (leave empty "" to disable)
$WebhookUrl = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S"

# Modrinth API base URL
$ModrinthBaseUrl = "https://api.modrinth.com/v2"

# Balanced thresholds
$SizeDiffPercentThreshold = 0.15     # 15%
$SizeDiffBytesThreshold   = 200kb    # ~200 KB

# Known cheat client IDs / package markers (1 = JA)
$CheatIdsOrPackages = @(
    "meteorclient",
    "wurst",
    "wurstclient",
    "aristois",
    "futureclient",
    "rusherhack",
    "impact",
    "lambda",
    "xenon",
    "kypton",
    "argon",
    "osmium",
    "glazed",
    "clickcrystal",
    "walksy",
    "gypsyy",
    "sakurwa",
    "lucid",       # "lucid argon"
    "anchorhack",
    "optimizer"
)

# Suspicious class/file name fragments (2 = JA)
$SuspiciousClassNameFragments = @(
    "killaura",
    "crystalaura",
    "autoclick",
    "triggerbot",
    "reach",
    "velocity",
    "aimassist"
)

# ------------------------------------------------
# Helper: detect running Minecraft instance
# ------------------------------------------------
function Get-RunningMinecraftPath {
    $javaProcs = Get-Process java,javaw -ErrorAction SilentlyContinue
    foreach ($p in $javaProcs) {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
            if (-not $cmd) { continue }

            # Prefer explicit -gameDir
            if ($cmd -match "-gameDir\s+""?([^""\s]+)""?") {
                $path = $matches[1].Trim('"')
                if (Test-Path $path) { return $path }
            }

            # Vanilla / Forge / Fabric: contains .minecraft
            if ($cmd -match "([A-Za-z]:\\[^""]*?\.minecraft)") {
                $path = $matches[1].Trim('"')
                if (Test-Path $path) { return $path }
            }

            # Prism/MultiMC/PolyMC: instances\<instance>\.minecraft or \minecraft
            if ($cmd -match "instances\\([^""\s]+)\\minecraft") {
                $instance = $matches[1]
                $guess1 = Join-Path "$env:APPDATA\PrismLauncher\instances" $instance
                $guess2 = Join-Path "$env:APPDATA\MultiMC\instances" $instance
                foreach ($g in @($guess1, $guess2)) {
                    if (Test-Path (Join-Path $g ".minecraft")) {
                        return (Join-Path $g ".minecraft")
                    }
                    if (Test-Path (Join-Path $g "minecraft")) {
                        return (Join-Path $g "minecraft")
                    }
                }
            }

            # Lunar Client
            if ($cmd -match "\.lunarclient\\") {
                $full = "$env:USERPROFILE\.lunarclient\offline\1.8"
                if (Test-Path $full) { return $full }
            }

            # Feather
            if ($cmd -match "feather") {
                $full = "$env:APPDATA\Feather\minecraft"
                if (Test-Path $full) { return $full }
            }

            # Badlion
            if ($cmd -match "badlion") {
                $full = "$env:APPDATA\.badlionclient\minecraft"
                if (Test-Path $full) { return $full }
            }

        } catch {}
    }

    return $null
}

# ------------------------------------------------
# Modrinth: get official file size for a mod
# ------------------------------------------------
$ModrinthSizeCache = @{}

function Get-ModrinthSize {
    param(
        [string]$FileNameWithoutExtension  # e.g. "fabric-api-0.102.0+1.21" or "fabric-api"
    )

    $key = $FileNameWithoutExtension.ToLower()

    if ($ModrinthSizeCache.ContainsKey($key)) {
        return $ModrinthSizeCache[$key]
    }

    # Try to strip version suffix: modname-1.2.3 → modname
    $clean = $key -replace "-\d+(\.\d+)*.*",""

    $url = "$ModrinthBaseUrl/search?query=$clean"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $res = Invoke-RestMethod -Uri $url -Method GET -ErrorAction Stop

        if ($res.hits.Count -gt 0) {
            $proj = $res.hits[0].project_id
            $vurl = "$ModrinthBaseUrl/project/$proj/version"
            $versionData = Invoke-RestMethod -Uri $vurl -Method GET -ErrorAction Stop

            if ($versionData[0].files[0].size) {
                $size = [int]$versionData[0].files[0].size
                $ModrinthSizeCache[$key] = $size
                return $size
            }
        }
    } catch {
        $ModrinthSizeCache[$key] = $null
        return $null
    }

    $ModrinthSizeCache[$key] = $null
    return $null
}

# ------------------------------------------------
# Analyze a single mod (size + cheat packages + suspicious classes)
# ------------------------------------------------
function Analyze-Mod {
    param(
        [string]$JarPath,
        [string]$ModName
    )

    $LocalSize = (Get-Item $JarPath).Length
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($ModName)

    # 1) Modrinth size check
    $ModrinthSize = Get-ModrinthSize -FileNameWithoutExtension $BaseName
    $SizeSuspicious = $false
    $SizeReason = $null

    if ($ModrinthSize -ne $null -and $ModrinthSize -gt 0) {
        $absDiff = [math]::Abs($ModrinthSize - $LocalSize)
        $pctDiff = $absDiff / [double]$ModrinthSize

        # Balanced: require BOTH % and absolute difference
        if ($pctDiff -gt $SizeDiffPercentThreshold -and $absDiff -gt $SizeDiffBytesThreshold) {
            $SizeSuspicious = $true
            $SizeReason = "Size mismatch (local: $([math]::Round($LocalSize/1MB,2))MB, Modrinth: $([math]::Round($ModrinthSize/1MB,2))MB, diff: $([math]::Round($pctDiff*100,1))%)"
        }
    }

    # 2) Extract JAR for deeper checks
    $TempDir = Join-Path $env:TEMP ("scan_" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $TempDir | Out-Null

    $PackageHits = @()
    $ClassHits   = @()

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($JarPath, $TempDir)

        $files = Get-ChildItem $TempDir -Recurse -File

        foreach ($f in $files) {
            $relPath = $f.FullName.Substring($TempDir.Length).ToLower()

            # 2.1 known cheat packages / IDs
            foreach ($id in $CheatIdsOrPackages) {
                if ($relPath -match [regex]::Escape($id.ToLower())) {
                    $PackageHits += $id
                }
            }

            # 2.2 suspicious class names by filename only (no content scanning)
            if ($f.Extension -eq ".class") {
                $fn = $f.Name.ToLower()
                foreach ($frag in $SuspiciousClassNameFragments) {
                    if ($fn -match [regex]::Escape($frag)) {
                        $ClassHits += $frag
                    }
                }
            }

            # 2.3 metadata IDs (fabric.mod.json / mods.toml / mcmod.info)
            if ($f.Name -match "fabric\.mod\.json|mods\.toml|mcmod\.info") {
                try {
                    $txt = Get-Content $f.FullName -Raw
                    $lower = $txt.ToLower()
                    foreach ($id in $CheatIdsOrPackages) {
                        if ($lower -match [regex]::Escape($id.ToLower())) {
                            $PackageHits += $id
                        }
                    }
                } catch {}
            }
        }

        $PackageHits = $PackageHits | Select-Object -Unique
        $ClassHits   = $ClassHits   | Select-Object -Unique

    } catch {
        # ignore extraction errors here; they do not auto-flag
    } finally {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # 3) Decide if suspicious
    $Reasons = @()
    $IsSuspicious = $false

    if ($SizeSuspicious -and $SizeReason) {
        $IsSuspicious = $true
        $Reasons += $SizeReason
    }

    if ($PackageHits.Count -gt 0) {
        $IsSuspicious = $true
        $Reasons += "Known cheat client/package: " + ($PackageHits -join ", ")
    }

    # Class names: be conservative: require at least 3 distinct suspicious fragments
    if ($ClassHits.Count -ge 3) {
        $IsSuspicious = $true
        $Reasons += "Multiple suspicious class names: " + ($ClassHits -join ", ")
    }

    return [PSCustomObject]@{
        ModName        = $ModName
        LocalSize      = $LocalSize
        ModrinthSize   = $ModrinthSize
        SizeSuspicious = $SizeSuspicious
        PackageHits    = $PackageHits
        ClassHits      = $ClassHits
        IsSuspicious   = $IsSuspicious
        Reason         = ($Reasons -join " | ")
    }
}

# ------------------------------------------------
# Optional: webhook
# ------------------------------------------------
function Send-Webhook {
    param(
        [array]$CheatMods
    )

    if (-not $WebhookUrl) { return }

    try {
        if ($CheatMods.Count -gt 0) {
            $descLines = @()
            foreach ($m in $CheatMods) {
                $descLines += "❌ $($m.ModName) — $($m.Reason)"
            }
            $embed = @{
                title = "🚨 Suspicious Mods Found (Size/Package/Class check)"
                color = 16711680
                description = ($descLines -join "`n")
            }
        } else {
            $embed = @{
                title = "✅ Mods Clean (balanced size & cheat check)"
                color = 65280
                description = "No suspicious mods detected."
            }
        }

        $payload = @{
            embeds = @($embed)
        } | ConvertTo-Json -Depth 5

        Invoke-RestMethod -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json" | Out-Null
    } catch {
        Write-Host "⚠ Webhook error: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# ------------------------------------------------
# MAIN
# ------------------------------------------------
Write-Host "Detecting running Minecraft instance..." -ForegroundColor Cyan
$MinecraftPath = Get-RunningMinecraftPath

if (-not $MinecraftPath) {
    Write-Host "❌ No running Minecraft instance detected. Start the client first." -ForegroundColor Red
    Read-Host "Press ENTER to exit"
    exit
}

Write-Host "🟢 Using instance:" -ForegroundColor Green
Write-Host "   $MinecraftPath"
Write-Host ""

$ModsPath = Join-Path $MinecraftPath "mods"
if (-not (Test-Path $ModsPath)) {
    Write-Host "❌ Mods folder not found at: $ModsPath" -ForegroundColor Red
    Read-Host "Press ENTER to exit"
    exit
}

$ModFiles = Get-ChildItem $ModsPath -Filter "*.jar"
if ($ModFiles.Count -eq 0) {
    Write-Host "⚠ No .jar mods found in: $ModsPath" -ForegroundColor Yellow
    Read-Host "Press ENTER to exit"
    exit
}

Write-Host "🔍 Scanning mods in: $ModsPath" -ForegroundColor Cyan
Write-Host ""

$SuspiciousMods = @()

foreach ($mod in $ModFiles) {
    Write-Host "Analyzing: $($mod.Name)" -ForegroundColor Yellow
    $result = Analyze-Mod -JarPath $mod.FullName -ModName $mod.Name

    if ($result.ModrinthSize -ne $null) {
        Write-Host "  Local size:    $([math]::Round($result.LocalSize / 1MB,2)) MB"
        Write-Host "  Modrinth size: $([math]::Round($result.ModrinthSize / 1MB,2)) MB"
    } else {
        Write-Host "  Modrinth size: n/a (not found)" -ForegroundColor DarkYellow
    }

    if ($result.PackageHits.Count -gt 0) {
        Write-Host "  Cheat packages: $($result.PackageHits -join ', ')" -ForegroundColor Red
    }
    if ($result.ClassHits.Count -gt 0) {
        Write-Host "  Suspicious class names: $($result.ClassHits -join ', ')" -ForegroundColor DarkYellow
    }

    if ($result.IsSuspicious) {
        Write-Host "  => 🚨 FLAGGED: $($result.Reason)" -ForegroundColor Red
        $SuspiciousMods += $result
    } else {
        Write-Host "  => ✅ OK" -ForegroundColor Green
    }

    Write-Host ""
}

Write-Host "================ SCAN RESULT ================" -ForegroundColor Cyan
Write-Host "Mods scanned:     $($ModFiles.Count)" -ForegroundColor White
Write-Host "Suspicious mods:  $($SuspiciousMods.Count)" -ForegroundColor Yellow

foreach ($s in $SuspiciousMods) {
    Write-Host ""
    Write-Host "❌ $($s.ModName)" -ForegroundColor Red
    Write-Host "   Reason: $($s.Reason)" -ForegroundColor Yellow
}

Send-Webhook -CheatMods $SuspiciousMods

Write-Host ""
Write-Host "Scan completed (balanced mode)." -ForegroundColor Green
Read-Host "Press ENTER to exit"
