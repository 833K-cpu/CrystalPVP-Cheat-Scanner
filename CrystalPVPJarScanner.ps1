# CrystalPVPJarScanner - Run-Time Mod Scanner
# Scans only currently running Minecraft instances
# Flags known cheats and size anomalies

$WebhookUrl = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S"  # Insert your webhook here

function Start-CheatScan {
    try {
        Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
        Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

        # --- Detect running Minecraft process ---
        $MinecraftPath = $null
        $javaProcesses = Get-Process java,javaw -ErrorAction SilentlyContinue

        foreach ($p in $javaProcesses) {
            try {
                $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
                if ($cmd -match "-gameDir\s+""?([^""\s]+)""?") {
                    $path = $matches[1]
                    if (Test-Path $path) {
                        $MinecraftPath = $path
                        break
                    }
                } elseif ($cmd -match "([a-zA-Z]:\\.*?\.minecraft)") {
                    $path = $matches[1]
                    if (Test-Path $path) {
                        $MinecraftPath = $path
                        break
                    }
                }
            } catch {}
        }

        if (-not $MinecraftPath) {
            Write-Host "❌ No running Minecraft detected. Exiting..."
            return
        }

        $ModsPath = Join-Path $MinecraftPath "mods"
        if (-not (Test-Path $ModsPath)) {
            Write-Host "❌ Mods folder not found: $ModsPath"
            return
        }

        $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction Stop
        $CheatMods = @()
        $Total = $ModFiles.Count
        $Current = 0

        # --- Send initial webhook ---
        Send-WebhookProgress -Current 0 -Total $Total

        foreach ($Mod in $ModFiles) {
            $Current++
            Write-Host "🔍 Analyzing [$Current / $Total]: $($Mod.Name)" -ForegroundColor DarkGray

            $Analysis = Analyze-Mod -JarPath $Mod.FullName -ModName $Mod.Name
            if ($Analysis.IsSuspicious) {
                $CheatMods += $Analysis
            }

            # Update webhook with progress
            Send-WebhookProgress -Current $Current -Total $Total
        }

        # --- Final results webhook ---
        Send-WebhookResults -CheatMods $CheatMods

        Write-Host "`nScan completed." -ForegroundColor Green
        Read-Host "Press Enter to exit..."
    } catch {
        Write-Host "❌ Fatal error: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit..."
    }
}

function Analyze-Mod {
    param([string]$JarPath, [string]$ModName)

    $TempDir = Join-Path $env:TEMP ("scan_" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $TempDir | Out-Null

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($JarPath, $TempDir)

        $CheatSignatures = Get-CheatSignatures
        $FoundCheats = @()

        $LocalSizeMB = [math]::Round((Get-Item $JarPath).Length / 1MB, 2)
        $Files = Get-ChildItem $TempDir -Recurse -File

        foreach ($File in $Files) {
            # Check package/metadata for known cheats
            if ($File.Name -match "fabric\.mod\.json|mcmod\.info") {
                try {
                    $Json = Get-Content $File.FullName -Raw | ConvertFrom-Json
                    if ($Json.id -and ($CheatSignatures -contains $Json.id.ToLower())) {
                        $FoundCheats += $Json.id
                    }
                } catch {}
            }

            $PathLower = $File.FullName.ToLower()
            foreach ($sig in $CheatSignatures) {
                if ($PathLower -match $sig) { $FoundCheats += $sig }
            }
        }

        $FoundCheats = $FoundCheats | Select-Object -Unique

        return [PSCustomObject]@{
            Mod = $ModName
            IsSuspicious = ($FoundCheats.Count -gt 0)
            Reason = if ($FoundCheats.Count -gt 0) { "Known cheat: $($FoundCheats -join ', ')" } else { "" }
        }

    } catch {
        return [PSCustomObject]@{
            Mod = $ModName
            IsSuspicious = $false
            Reason = "Scan error — file may be protected or corrupted"
        }
    } finally {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-CheatSignatures {
    return @("meteorclient","wurstclient","aristois","futureclient","rusherhack","impact","xenon","optimizer","walksy","glazed","clickcrystal")
}

function Send-WebhookProgress {
    param([int]$Current, [int]$Total)

    if (-not $WebhookUrl) { return }
    try {
        $payload = @{
            content = "🔍 Analysing mods... [$Current / $Total]"
        } | ConvertTo-Json
        Invoke-RestMethod -Uri $WebhookUrl -Method PATCH -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
    } catch {}
}

function Send-WebhookResults {
    param([array]$CheatMods)
    if (-not $WebhookUrl) { return }

    try {
        if ($CheatMods.Count -eq 0) {
            $embed = @{ title="✅ All mods clean"; color=65280; description="No suspicious mods detected." }
        } else {
            $embed = @{ title="🚨 Suspicious Mods Found"; color=16711680; description=($CheatMods | ForEach-Object { "❌ $($_.Mod) — $($_.Reason)" }) -join "`n" }
        }
        $payload = @{ embeds=@($embed) } | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json"
    } catch {}
}

# --- START SCAN ---
Start-CheatScan
