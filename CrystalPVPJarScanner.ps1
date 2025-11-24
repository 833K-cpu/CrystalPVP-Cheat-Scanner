# CrystalPVP Cheat Scanner – Auto-running-instance + Modrinth Size Verification
# No manual folder input – Only scans the currently running instance

$ErrorActionPreference = "SilentlyContinue"

Write-Host "=== CrystalPVP Cheat Scanner ===" -ForegroundColor Cyan
Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow
Write-Host ""

# -------------------------------
# 1) Detect the currently running Minecraft instance
# -------------------------------
function Get-RunningMinecraftPath {

    $javaProcs = Get-Process java,javaw -ErrorAction SilentlyContinue
    foreach ($p in $javaProcs) {

        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
            if (-not $cmd) { continue }

            # Most reliable: -gameDir "<path>"
            if ($cmd -match "-gameDir\s+""?([^""\s]+)""?") {
                $path = $matches[1]
                if (Test-Path $path) { return $path }
            }

            # Vanilla / Forge / Fabric: .minecraft in path
            if ($cmd -match "([A-Za-z]:\\[^""]*?\.minecraft)") {
                $path = $matches[1]
                if (Test-Path $path) { return $path }
            }

            # PrismLauncher / PolyMC / MultiMC
            if ($cmd -match "instances\\([^""\s]+)\\minecraft") {
                $instance = $matches[1]
                $full = "$env:APPDATA\PrismLauncher\instances\$instance\.minecraft"
                if (Test-Path $full) { return $full }
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

$MinecraftPath = Get-RunningMinecraftPath

if (-not $MinecraftPath) {
    Write-Host "❌ No running Minecraft instance detected." -ForegroundColor Red
    exit
}

Write-Host "🟢 Detected running Minecraft instance:" -ForegroundColor Green
Write-Host "$MinecraftPath"
Write-Host ""

$ModsPath = Join-Path $MinecraftPath "mods"
if (-not (Test-Path $ModsPath)) {
    Write-Host "❌ Mods folder not found in: $MinecraftPath" -ForegroundColor Red
    exit
}

# -------------------------------
# 2) Get mods
# -------------------------------
$ModFiles = Get-ChildItem $ModsPath -Filter "*.jar"
if ($ModFiles.Count -eq 0) {
    Write-Host "⚠ No mods found." -ForegroundColor Yellow
    exit
}

Write-Host "🔍 Scanning mods in: $ModsPath" -ForegroundColor Cyan
Write-Host ""

# -------------------------------
# 3) Check Modrinth size
# -------------------------------
function Get-ModrinthSize {
    param([string]$FileName)

    # remove version from filename: modname-1.3.2.jar → modname
    $clean = $FileName -replace "-\d+(\.\d+)*.*",""
    $clean = $clean -replace "\.jar",""

    $url = "https://api.modrinth.com/v2/search?query=$clean"

    try {
        $res = Invoke-RestMethod -Uri $url -Method GET -ErrorAction Stop

        if ($res.hits.Count -gt 0) {
            $proj = $res.hits[0].project_id
            $vurl = "https://api.modrinth.com/v2/project/$proj/version"
            $versionData = Invoke-RestMethod -Uri $vurl -Method GET -ErrorAction Stop

            if ($versionData[0].files[0].size) {
                return [int]$versionData[0].files[0].size
            }
        }
    } catch {}

    return $null
}

# -------------------------------
# 4) Scan mods
# -------------------------------
foreach ($Mod in $ModFiles) {

    $LocalSize = (Get-Item $Mod.FullName).Length
    Write-Host "Mod: $($Mod.Name)" -ForegroundColor Yellow
    Write-Host "Local Size: $([math]::Round($LocalSize / 1MB,2)) MB"

    $MRSize = Get-ModrinthSize -FileName $Mod.Name

    if ($MRSize -eq $null) {
        Write-Host "Modrinth: ❓ Not found" -ForegroundColor DarkYellow
        Write-Host ""
        continue
    }

    Write-Host "Modrinth Size: $([math]::Round($MRSize / 1MB,2)) MB"

    # tolerance: allow 5% difference (compression differences)
    $diff = [math]::Abs($MRSize - $LocalSize)
    $allowed = $MRSize * 0.05

    if ($diff -gt $allowed) {
        Write-Host "🚨 SIZE MISMATCH → POSSIBLE CHEAT OR MODIFIED JAR" -ForegroundColor Red
    } else {
        Write-Host "✅ Size OK" -ForegroundColor Green
    }

    Write-Host ""
}

Write-Host "=== Scan complete ===" -ForegroundColor Cyan
Read-Host "Press ENTER to exit"
