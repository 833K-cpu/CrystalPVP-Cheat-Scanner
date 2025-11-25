# CrystalPVPJarScanner.ps1
# Scans ONLY the currently running Minecraft instance's mods
# Flags mods based on known cheat clients + suspicious class names (conservative)

$ErrorActionPreference = "SilentlyContinue"

function Start-CheatScan {
    Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    $mcPath = Get-RunningMinecraftPath
    if (-not $mcPath) {
        Write-Host "❌ No running Minecraft instance with a valid game directory was found." -ForegroundColor Red
        Write-Host "Make sure Minecraft is running before you start this scanner." -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        return
    }

    $modsPath = Join-Path $mcPath "mods"
    if (-not (Test-Path $modsPath)) {
        Write-Host "❌ 'mods' folder not found in running instance:" -ForegroundColor Red
        Write-Host "   $modsPath" -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        return
    }

    $modFiles = Get-ChildItem $modsPath -Filter "*.jar" -ErrorAction Stop
    if ($modFiles.Count -eq 0) {
        Write-Host "⚠ No .jar mods found in:" -ForegroundColor Yellow
        Write-Host "   $modsPath" -ForegroundColor Yellow
        Read-Host "Press Enter to exit..."
        return
    }

    Write-Host ""
    Write-Host "Detected Minecraft instance:" -ForegroundColor Green
    Write-Host "   $mcPath"
    Write-Host ""
    Write-Host "Scanning mods in:" -ForegroundColor Green
    Write-Host "   $modsPath"
    Write-Host ""

    $total = $modFiles.Count
    $index = 0
    $flagged = @()

    foreach ($mod in $modFiles) {
        $index++
        Write-Host "Analyzing mods... [ $index / $total ] $($mod.Name)" -ForegroundColor Cyan

        $result = Analyze-Mod -JarPath $mod.FullName -ModName $mod.Name

        if ($result.IsSuspicious) {
            Write-Host "  -> 🚨 FLAGGED: $($result.Reason)" -ForegroundColor Red
            $flagged += $result
        } else {
            Write-Host "  -> ✅ Clean" -ForegroundColor Green
        }

        Write-Host ""
    }

    # ---------- Summary ----------
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "              SCAN RESULTS                " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Mods scanned:    $total" -ForegroundColor White
    Write-Host "Suspicious mods: $($flagged.Count)" -ForegroundColor Yellow
    Write-Host ""

    if ($flagged.Count -eq 0) {
        Write-Host "✅ No suspicious mods detected." -ForegroundColor Green
    } else {
        foreach ($m in $flagged) {
            Write-Host "❌ $($m.ModName)" -ForegroundColor Red
            Write-Host "   Reason: $($m.Reason)" -ForegroundColor Yellow
            if ($m.Hits -and $m.Hits.Count -gt 0) {
                Write-Host "   Hits:   $($m.Hits -join ', ')" -ForegroundColor DarkYellow
            }
            Write-Host ""
        }
    }

    Write-Host "Scan finished at: $(Get-Date)" -ForegroundColor Yellow
    Read-Host "Press Enter to exit..."
}

# ------------------------------------------------
# Detect running Minecraft gameDir (ONLY running)
# ------------------------------------------------
function Get-RunningMinecraftPath {
    $javaProcs = Get-Process java,javaw -ErrorAction SilentlyContinue |
                 Sort-Object StartTime -Descending

    foreach ($p in $javaProcs) {
        try {
            $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)"
            $cmd = $proc.CommandLine
            if (-not $cmd) { continue }

            # Preferred: -gameDir "<path>"
            if ($cmd -match "-gameDir\s+""([^""]+)""") {
                $path = $matches[1].Trim()
                if (Test-Path (Join-Path $path "mods")) {
                    return $path
                }
            } elseif ($cmd -match "-gameDir\s+([^\s]+)") {
                $path = $matches[1].Trim('"')
                if (Test-Path (Join-Path $path "mods")) {
                    return $path
                }
            }

            # Vanilla / Forge / Fabric: contains .minecraft
            if ($cmd -match "([A-Za-z]:\\[^""]*?\.minecraft)") {
                $path = $matches[1].Trim('"')
                if (Test-Path (Join-Path $path "mods")) {
                    return $path
                }
            }
        } catch {
            # ignore process we can't read
        }
    }

    return $null
}

# ------------------------------------------------
# Analyze a single mod JAR
# ------------------------------------------------
function Analyze-Mod {
    param(
        [string]$JarPath,
        [string]$ModName
    )

    $tempDir = Join-Path $env:TEMP ("cpvp_scan_" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    $hits = @()
    $isSuspicious = $false
    $reasons = @()

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        [System.IO.Compression.ZipFile]::ExtractToDirectory($JarPath, $tempDir)

        $pkgResult   = Scan-CheatPackages     -ExtractPath $tempDir
        $classResult = Scan-SuspiciousClasses -ExtractPath $tempDir

        if ($pkgResult.Hits.Count -gt 0) {
            $isSuspicious = $true
            $reasons += "Known cheat client/package detected"
            $hits += $pkgResult.Hits
        }

        # For class-based detection, be conservative:
        # require at least 3 distinct suspicious names
        if ($classResult.Hits.Count -ge 3) {
            $isSuspicious = $true
            $reasons += "Multiple suspicious class names found"
            $hits += $classResult.Hits
        }

    } catch {
        # extraction or read error is NOT automatically suspicious
        $reasons += "Scan error — file may be protected or corrupted"
    } finally {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    $hits = $hits | Select-Object -Unique

    return [PSCustomObject]@{
        ModName      = $ModName
        IsSuspicious = $isSuspicious
        Reason       = if ($reasons.Count -gt 0) { $reasons -join "; " } else { "" }
        Hits         = $hits
    }
}

# ------------------------------------------------
# Scan for known cheat clients / packages
# ------------------------------------------------
function Scan-CheatPackages {
    param([string]$ExtractPath)

    $hits = @()

    # only stable, known cheat identifiers (very low false-positive chance)
    $cheatIds = @(
        "meteorclient",
        "net.wurst",
        "wurstclient",
        "aristois",
        "futureclient",
        "rusherhack",
        "xenon",
        "liquidbounce",
        "riseclient",
        "novoline",
        "kwerk",
        "pulsive",
        "orcaclient"
   
    )

    $files = Get-ChildItem $ExtractPath -Recurse -File -ErrorAction SilentlyContinue

    foreach ($f in $files) {
        $rel = $f.FullName.Substring($ExtractPath.Length).ToLower()

        foreach ($id in $cheatIds) {
            if ($rel -match [regex]::Escape($id.ToLower())) {
                $hits += "package:$id"
            }
        }

        # metadata IDs
        if ($f.Name -match "fabric\.mod\.json|mods\.toml|mcmod\.info") {
            try {
                $txt = Get-Content $f.FullName -Raw -ErrorAction Stop
                $low = $txt.ToLower()
                foreach ($id in $cheatIds) {
                    if ($low -match [regex]::Escape($id.ToLower())) {
                        $hits += "meta:$id"
                    }
                }
            } catch {}
        }
    }

    $hits = $hits | Select-Object -Unique
    return [PSCustomObject]@{
        Hits = $hits
    }
}

# ------------------------------------------------
# Scan for suspicious class names (very conservative)
# ------------------------------------------------
function Scan-SuspiciousClasses {
    param([string]$ExtractPath)

    $hits = @()
    $classFiles = Get-ChildItem $ExtractPath -Recurse -Filter "*.class" -ErrorAction SilentlyContinue

    # suspicious fragments – but require several to trigger
    $fragments = @(
        "killaura",
        "crystalaura",
        "autoclick",
        "triggerbot",
        "aimassist",
        "velocity",
        "scaffold",
        "flyhack",
        "nofall",
        "autocrystal",
        "anchormacro"

    )

    foreach ($cf in $classFiles) {
        try {
            $bytes = [IO.File]::ReadAllBytes($cf.FullName)
            $text  = [Text.Encoding]::ASCII.GetString($bytes)

            foreach ($frag in $fragments) {
                if ($text -match $frag) {
                    $hits += "class:$frag"
                }
            }
        } catch {}
    }

    $hits = $hits | Select-Object -Unique
    return [PSCustomObject]@{
        Hits = $hits
    }
}

# ----------------- ENTRY POINT -------------------
Start-CheatScan
