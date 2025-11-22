# Enhanced Minecraft Screenshare Scanner
# Optimized, More Stable, Error-Handled Version
# --- FULL REWORK FOR RELIABILITY AND ZERO CRASHES ---

# SAFE: Webhook removed for security – add your webhook in the variable below
$WebhookUrl = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S"  # <--- Insert your webhook here

function Start-CheatScan {
    try {
        Write-Host "=== MINECRAFT SCREENSHARE SCANNER ===" -ForegroundColor Cyan
        Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

        # Auto-detect Minecraft directory OR use the one from a running Minecraft process
        $MinecraftPath = $null

        # 1) Check running Minecraft processes first
        $runningMC = Get-Process java,wjava,javaw -ErrorAction SilentlyContinue | Where-Object {
            $_.Path -and (Get-Command $_.Path -ErrorAction SilentlyContinue)
        }

        $foundPath = $null
        foreach ($p in $runningMC) {
            try {
                $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
                if ($cmd -match "\.minecraft") {
                    $match = [regex]::Match($cmd, "(.*?\\\.minecraft)")
                    if ($match.Success) {
                        $foundPath = $match.Groups[1].Value
                        break
                    }
                }
            } catch {}
        }

        if ($foundPath) {
            Write-Host "🟢 Running Minecraft detected — path automatically extracted:" -ForegroundColor Green
            Write-Host " → $foundPath" -ForegroundColor Yellow
            $MinecraftPath = $foundPath
        }
        else {
            # 2) Fallback: Standard Path
            $MinecraftPath = Join-Path $env:APPDATA ".minecraft"
            if (Test-Path $MinecraftPath) {
                Write-Host "🟡 Minecraft not running — using default path: $MinecraftPath" -ForegroundColor Yellow
            }
        }

        # 3) If nothing found, ask user
        if (-not (Test-Path $MinecraftPath)) {
            Write-Host "❌ Minecraft Verzeichnis konnte nicht automatisch gefunden werden." -ForegroundColor Red
            Write-Host "Bitte gib den Pfad manuell ein:" -ForegroundColor Yellow
            $MinecraftPath = Read-Host "Pfad"
        }

        if (-not (Test-Path $MinecraftPath)) {
            throw "Minecraft directory not found: $MinecraftPath"
        }

        $ModsPath = Join-Path $MinecraftPath "mods"
        if (-not (Test-Path $ModsPath)) {
            throw "No mods folder found at: $ModsPath"
        }

        Write-Host "\n🔍 Scanning mods in: $ModsPath" -ForegroundColor Green

        # Get mod JARs
        $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction Stop
        $CheatMods = @()

        foreach ($Mod in $ModFiles) {
            Write-Host "\nAnalyzing: $($Mod.Name)" -ForegroundColor DarkGray
            $Analysis = Analyze-ModContent -JarPath $Mod.FullName -ModName $Mod.Name

            if ($Analysis.IsSuspicious) {
                Write-Host "🚨 Suspicious: $($Analysis.Reason)" -ForegroundColor Red
                $CheatMods += $Analysis
            } else {
                Write-Host "✅ Clean" -ForegroundColor Green
            }
        }

        Write-Host "\n===== SCAN RESULTS =====" -ForegroundColor Cyan
        Write-Host "Mods scanned: $($ModFiles.Count)" -ForegroundColor White
        Write-Host "Suspicious mods: $($CheatMods.Count)" -ForegroundColor Yellow

        foreach ($Item in $CheatMods) {
            Write-Host "\n❌ $($Item.Mod)" -ForegroundColor Red
            Write-Host "   ➤ Reason: $($Item.Reason)" -ForegroundColor Yellow
            Write-Host "   ➤ Confidence: $($Item.Confidence)%" -ForegroundColor Cyan
        }

        Send-WebhookResults -CheatMods $CheatMods

        Write-Host "\nScan completed." -ForegroundColor Green
        Write-Host "Press Enter to exit..." -ForegroundColor Gray
        Read-Host

    } catch {
        Write-Host "❌ Fatal error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Press Enter to exit..." -ForegroundColor Gray
        Read-Host
    }
}

function Analyze-ModContent {
    param(
        [string]$JarPath,
        [string]$ModName
    )

    $TempDir = Join-Path $env:TEMP ("scan_" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $TempDir | Out-Null

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($JarPath, $TempDir)

        $Signatures = Scan-ForCheatSignatures -ExtractPath $TempDir
        $Packages = Scan-ForPackagePatterns -ExtractPath $TempDir
        $Methods = Scan-ClassFiles -ExtractPath $TempDir
        $Meta = Scan-ModMetadata -ExtractPath $TempDir

        $TotalConfidence = $Signatures.Confidence + $Packages.Confidence + $Methods.Confidence + $Meta.Confidence
        $Reasons = $Signatures.Reasons + $Packages.Reasons + $Methods.Reasons + $Meta.Reasons

        return [PSCustomObject]@{
            Mod = $ModName
            IsSuspicious = ($TotalConfidence -ge 60 -or $Reasons.Count -gt 1)
            Confidence = [Math]::Min($TotalConfidence, 100)
            Reason = ($Reasons -join "; ")
        }

    } catch {
        return [PSCustomObject]@{
            Mod = $ModName
            IsSuspicious = $true
            Confidence = 50
            Reason = "Scan error — file may be protected or corrupted"
        }
    } finally {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

##########################
# Detection Subsystems
##########################

function Scan-ForCheatSignatures {
    param([string]$ExtractPath)

    $signs = @()
    $confidence = 0

    $Patterns = @(
        @{ Pattern = "meteorclient"; Score = 80 }
        @{ Pattern = "net\.wurst"; Score = 95 }
        @{ Pattern = "aristois"; Score = 80 }
        @{ Pattern = "rusherhack"; Score = 85 }
        @{ Pattern = "futureclient"; Score = 85 }
        @{ Pattern = "liquidbounce"; Score = 90 }
        @{ Pattern = "killaura"; Score = 80 }
        @{ Pattern = "reach"; Score = 70 }
        @{ Pattern = "flyhack"; Score = 80 }
    )

    $Files = Get-ChildItem $ExtractPath -Recurse -File -ErrorAction SilentlyContinue
    foreach ($File in $Files) {
        try {
            $Content = Get-Content $File.FullName -Raw -ErrorAction Stop
            foreach ($p in $Patterns) {
                if ($Content -match $p.Pattern) {
                    $signs += $p.Pattern
                    $confidence += $p.Score
                }
            }
        } catch {}
    }

    return @{ Reasons = $signs; Confidence = $confidence }
}

function Scan-ForPackagePatterns {
    param([string]$ExtractPath)

    $Packages = @(
        "meteorclient", "net.wurst", "aristois", "rusherhack", "baritone", "liquidbounce"
    )

    $reasons = @()
    $conf = 0

    $ClassFiles = Get-ChildItem $ExtractPath -Recurse -Filter "*.class"
    foreach ($File in $ClassFiles) {
        $path = $File.FullName.Replace($ExtractPath, "")
        foreach ($pkg in $Packages) {
            if ($path -match $pkg) {
                $reasons += "Package: $pkg"
                $conf += 40
            }
        }
    }

    return @{ Reasons = $reasons; Confidence = $conf }
}

function Scan-ClassFiles {
    param([string]$ExtractPath)

    $Suspicious = @(
        "killaura", "reach", "velocity", "fly", "nofall", "esp", "scaffold", "nuker"
    )

    $reasons = @()
    $conf = 0

    $Files = Get-ChildItem $ExtractPath -Recurse -Filter "*.class"
    foreach ($F in $Files) {
        try {
            $bytes = [IO.File]::ReadAllBytes($F.FullName)
            $text = [Text.Encoding]::ASCII.GetString($bytes)
            foreach ($sig in $Suspicious) {
                if ($text -match $sig) {
                    $reasons += "Method: $sig"
                    $conf += 30
                }
            }
        } catch {}
    }

    return @{ Reasons = $reasons; Confidence = $conf }
}

function Scan-ModMetadata {
    param([string]$ExtractPath)

    $reasons = @()
    $conf = 0

    $jsonFile = Get-ChildItem $ExtractPath -Recurse -Filter "fabric.mod.json"
    if ($jsonFile) {
        try {
            $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            $id = $json.id
            $bad = @("meteor-client", "wurst", "aristois", "future", "lambda")

            if ($bad -contains $id) {
                $reasons += "Cheat Mod ID: $id"
                $conf += 90
            }
        } catch {}
    }

    return @{ Reasons = $reasons; Confidence = $conf }
}

##########################
# Webhook Sender
##########################

function Send-WebhookResults {
    param([array]$CheatMods)

    if (-not $WebhookUrl) {
        Write-Host "⚠️ Webhook URL missing — skipping Discord report." -ForegroundColor Yellow
        return
    }

    try {
        $embed = if ($CheatMods.Count -gt 0) {
            @{ title = "🚨 Suspicious Mods Found"; color = 16711680; description = ($CheatMods | ForEach-Object { "❌ $($_.Mod) — $($_.Reason)" }) -join "`n" }
        } else {
            @{ title = "✅ System Clean"; color = 65280; description = "No suspicious mods detected." }
        }

        $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json"

        Write-Host "📨 Webhook sent." -ForegroundColor Green

    } catch {
        Write-Host "❌ Webhook error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# START
Start-CheatScan
