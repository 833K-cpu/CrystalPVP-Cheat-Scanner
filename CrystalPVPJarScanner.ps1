# CrystalPVPJarScanner.ps1
# Scans ONLY the currently running Minecraft instance's mods
# Flags mods based on known cheat clients + suspicious class names (conservative)

$ErrorActionPreference = "SilentlyContinue"

function Start-CheatScan {
    Clear-Host
    Write-Host "833K´s Cheat Analyser" -ForegroundColor Yellow
    Write-Host "Made by " -ForegroundColor DarkGray -NoNewline
    Write-Host "833K" -ForegroundColor White
    Write-Host ""

    # --- Minecraft uptime info (like Habibi design) ---
    $process = Get-Process javaw -ErrorAction SilentlyContinue
    if (-not $process) {
        $process = Get-Process java -ErrorAction SilentlyContinue
    }

    if ($process) {
        try {
            $p = $process | Select-Object -First 1
            $startTime = $p.StartTime
            $elapsedTime = (Get-Date) - $startTime

            Write-Host "{ Minecraft Uptime }" -ForegroundColor DarkCyan
            Write-Host "$($p.Name) PID $($p.Id) started at $startTime and running for $($elapsedTime.Hours)h $($elapsedTime.Minutes)m $($elapsedTime.Seconds)s"
            Write-Host ""
        } catch {}
    }

    Write-Host "Searching for running Minecraft instance..." -ForegroundColor DarkGray

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
    Write-Host "{ Detected Minecraft Instance }" -ForegroundColor DarkCyan
    Write-Host "GameDir: $mcPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "{ Mods Folder }" -ForegroundColor DarkCyan
    Write-Host "$modsPath" -ForegroundColor Green
    Write-Host ""

    $total   = $modFiles.Count
    $counter = 0
    $spinner = @("|", "/", "-", "\")
    $flagged = @()
    $clean   = @()

    # --------- Scanning with spinner (Habibi style) ---------
    foreach ($mod in $modFiles) {
        $counter++
        $spin = $spinner[$counter % $spinner.Length]

        Write-Host "`r[$spin] Scanning mods: $counter / $total" -ForegroundColor Yellow -NoNewline

        $result = Analyze-Mod -JarPath $mod.FullName -ModName $mod.Name

        if ($result.IsSuspicious) {
            $flagged += $result
        } else {
            $clean += $result
        }
    }

    # Clear spinner line
    Write-Host "`r$(' ' * 80)`r" -NoNewline
    Write-Host ""

    # ---------- Summary (Habibi style sections) ----------
    if ($clean.Count -gt 0) {
        Write-Host "{ Clean Mods }" -ForegroundColor DarkCyan
        foreach ($m in $clean) {
            Write-Host ("> {0,-40}" -f $m.ModName) -ForegroundColor Green
        }
        Write-Host ""
    }

    if ($flagged.Count -gt 0) {
        Write-Host "{ Cheat Mods }" -ForegroundColor DarkCyan
        foreach ($m in $flagged) {
            Write-Host "> $($m.ModName)" -ForegroundColor Red
            Write-Host "   Reason: $($m.Reason)" -ForegroundColor DarkMagenta
            if ($m.Hits -and $m.Hits.Count -gt 0) {
                Write-Host "   Hits:   $($m.Hits -join ', ')" -ForegroundColor DarkYellow
            }
        }
        Write-Host ""
    }

    if ($flagged.Count -eq 0) {
        Write-Host "✅ No suspicious mods detected." -ForegroundColor Green
        Write-Host ""
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
        "orcaclient",
        "GetTargetMargian",
        "ucoz",
        "bleachhack_outline",
        "Bad at the game? Try Lumina Client (luminaclient.com)",
        "Geteventbutton",
        "GetTargetM",
        "/net/wurstclient/hacks/ChatTranslatorHack.class",
        "3m!",
        "s)B!",
        "Jc]hdYo",
        "tsEK$",
        "hYx%J",
        "nXw]s",
        "6jc]Ku",
        ".lattia",
        "noweakattack",
        "nursultan",
        "p~,R",
        "B6&@",
        "rm &%",
        "e `9CZ",
        "vEwimWC",
        "988697",
        "GuqD$",
        "YPBC",
        "hitbox > exp",
        "Achilles",
        "st/mixin/KeyboardMixin",
        "self d",
        "gettargetmargain",
        "bleachhack_outline",
        "ucoz",
        "florens",
        "YZWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
        "geteventbutton",
        "]Ue8",
        "Onyx",
        "Wurst",
        "Meteor",
        "Hitboxes",
        "Vape",
        "Ares",
        "Aids Hack",
        "Aristoris",
        "Francium",
        "Skligga",
        "Platinium",
        "Self de",
        "coffe",
        "#]!"
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
        "anchormacro",
        "ucoz",
        "bleachhack_outline",
        "Bad at the game? Try Lumina Client (luminaclient.com)",
        "Geteventbutton",
        "GetTargetM",
        "/net/wurstclient/hacks/ChatTranslatorHack.class",
        "3m!",
        "s)B!",
        "Jc]hdYo",
        "tsEK$",
        "hYx%J",
        "nXw]s",
        "6jc]Ku",
        ".lattia",
        "noweakattack",
        "nursultan",
        "p~,R",
        "B6&@",
        "rm &%",
        "e `9CZ",
        "vEwimWC",
        "988697",
        "GuqD$",
        "YPBC",
        "hitbox > exp",
        "Achilles",
        "st/mixin/KeyboardMixin",
        "self d",
        "gettargetmargain",
        "bleachhack_outline",
        "ucoz",
        "florens",
        "YZWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
        "geteventbutton",
        "]Ue8",
        "Onyx",
        "Wurst",
        "Meteor",
        "Hitboxes",
        "Vape",
        "Ares",
        "Aids Hack",
        "Aristoris",
        "Francium",
        "Skligga",
        "Platinium",
        "Self de",
        "coffe",
        "#]!"
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
