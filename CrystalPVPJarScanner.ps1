<#
    CrystalPVPJarScanner.ps1
    ------------------------
    Advanced Minecraft Mod Scanner
    - Detects running Minecraft instance and scans its actual mods folder
    - Compatible with Vanilla, MultiMC, Prism, Modrinth, Modthint
    - Detects cheat clients and suspicious modules
    - Sends optional Discord webhook reports
#>

#region CONFIG

$Global:WebhookUrl = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S" # Insert your Discord webhook URL here
$Global:CheatSignatures = @(
    "meteorclient","minegame159","net.wurst","aristois","rusherhack",
    "futureclient","liquidbounce","riseclient","novoline","tenacity",
    "vape","sigma","impactclient","wurstclient","moonclient"
)
$Global:SuspiciousMethods = @(
    "killaura","reach","triggerbot","autoclick","aimassist",
    "flyhack","speedhack","bhop","nofall","scaffold","xray",
    "autototem","inventorymove","crystalaura"
)

#endregion CONFIG

#region CORE FUNCTIONS

function Get-RunningMinecraftModsPath {
    # Detect running Minecraft process and extract --gameDir or mods folder
    $runningMC = Get-Process java,javaw,wjava -ErrorAction SilentlyContinue
    foreach ($p in $runningMC) {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
            if ($cmd -match "--gameDir\s+([^\s]+)") {
                $gameDir = $matches[1]
                $modsDir = Join-Path $gameDir "mods"
                if (Test-Path $modsDir) { return $modsDir }
            }
            # fallback: check if command line contains .minecraft path
            if ($cmd -match "(.*?\.minecraft)") {
                $foundPath = $matches[1]
                $modsDir = Join-Path $foundPath "mods"
                if (Test-Path $modsDir) { return $modsDir }
            }
        } catch {}
    }
    # fallback default .minecraft
    $default = Join-Path $env:APPDATA ".minecraft\mods"
    if (Test-Path $default) { return $default }
    return $null
}

function Analyze-ModJar {
    param([string]$JarPath,[string]$ModName)
    $TempDir = Join-Path $env:TEMP ("scan_" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $TempDir | Out-Null

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($JarPath, $TempDir)

        $Detected = @()
        $Confidence = 0

        $Files = Get-ChildItem $TempDir -Recurse -File -ErrorAction SilentlyContinue
        foreach ($File in $Files) {
            try {
                $Content = Get-Content $File.FullName -Raw -ErrorAction Stop
                foreach ($sig in $Global:CheatSignatures) {
                    if ($Content -match $sig) {
                        $Detected += $sig
                        $Confidence += 80
                    }
                }
                foreach ($method in $Global:SuspiciousMethods) {
                    if ($Content -match $method) {
                        $Detected += "Method: $method"
                        $Confidence += 30
                    }
                }
            } catch {}
        }

        $TotalConfidence = [Math]::Min($Confidence,100)
        $IsSuspicious = ($TotalConfidence -ge 60 -or $Detected.Count -gt 0)

        return [PSCustomObject]@{
            Mod = $ModName
            IsSuspicious = $IsSuspicious
            Confidence = $TotalConfidence
            Reason = ($Detected -join "; ")
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

function Send-WebhookResults {
    param([array]$CheatMods)
    if (-not $Global:WebhookUrl) { Write-Host "⚠️ Webhook URL missing — skipping report."; return }

    $embed = if ($CheatMods.Count -gt 0) {
        @{ title="🚨 Suspicious Mods Detected"; color=16711680; description=($CheatMods | ForEach-Object { "❌ $($_.Mod) — $($_.Reason)" }) -join "`n" }
    } else {
        @{ title="✅ System Clean"; color=65280; description="No suspicious mods detected." }
    }

    $payload = @{ embeds=@($embed) } | ConvertTo-Json -Depth 5
    try { Invoke-RestMethod -Uri $Global:WebhookUrl -Method POST -Body $payload -ContentType "application/json"; Write-Host "📨 Webhook sent." -ForegroundColor Green }
    catch { Write-Host "❌ Webhook error: $($_.Exception.Message)" -ForegroundColor Red }
}

function Run-Scan {
    Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    $ModsPath = Get-RunningMinecraftModsPath
    if (-not $ModsPath) { throw "Could not find a valid mods folder." }
    Write-Host "🔍 Scanning mods in: $ModsPath" -ForegroundColor Green

    $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction Stop
    $CheatMods = @()

    foreach ($Mod in $ModFiles) {
        Write-Host "Analyzing: $($Mod.Name)" -ForegroundColor DarkGray
        $Analysis = Analyze-ModJar -JarPath $Mod.FullName -ModName $Mod.Name
        if ($Analysis.IsSuspicious) {
            Write-Host "🚨 Suspicious: $($Analysis.Reason)" -ForegroundColor Red
            $CheatMods += $Analysis
        } else {
            Write-Host "✅ Clean" -ForegroundColor Green
        }
    }

    Write-Host "`n===== SCAN RESULTS =====" -ForegroundColor Cyan
    Write-Host "Mods scanned: $($ModFiles.Count)" -ForegroundColor White
    Write-Host "Suspicious mods: $($CheatMods.Count)" -ForegroundColor Yellow

    foreach ($Item in $CheatMods) {
        Write-Host "❌ $($Item.Mod) — $($Item.Reason) — Confidence: $($Item.Confidence)%" -ForegroundColor Red
    }

    Send-WebhookResults -CheatMods $CheatMods
    Write-Host "`nScan completed." -ForegroundColor Green
}

#endregion CORE FUNCTIONS

# START SCAN
Run-Scan
