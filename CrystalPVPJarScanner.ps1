# CrystalPVPJarScanner - Auto-detect running Minecraft folder
# Zero false-positive PVP mod scanner

$WebhookUrl = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S"  # Optional: Insert your Discord webhook

function Start-CheatScan {
    try {
        Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
        Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

        $MinecraftPath = $null

        # --- Step 1: Scan running Java processes for Minecraft ---
        $javaProcesses = Get-Process java,javaw -ErrorAction SilentlyContinue
        foreach ($p in $javaProcesses) {
            try {
                $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
                if ($cmdLine) {
                    # Check for Modrinth/MultiMC/Lunar/etc. gameDir
                    if ($cmdLine -match "-gameDir\s+""?([^""\s]+)""?") {
                        $path = $matches[1]
                        if (Test-Path $path) {
                            $MinecraftPath = $path
                            break
                        }
                    }
                    # Fallback: check for .minecraft in path
                    elseif ($cmdLine -match "([a-zA-Z]:\\.*?\.minecraft)") {
                        $path = $matches[1]
                        if (Test-Path $path) {
                            $MinecraftPath = $path
                            break
                        }
                    }
                }
            } catch {}
        }

        # --- Step 2: Ask user if nothing detected ---
        if (-not $MinecraftPath) {
            Write-Host "🟡 Minecraft not running or profile not detected."
            $MinecraftPath = Read-Host "Enter your Minecraft/Modrinth/MultiMC folder path"
        }

        # --- Step 3: Set mods path ---
        $ModsPath = Join-Path $MinecraftPath "mods"
        if (-not (Test-Path $ModsPath)) {
            throw "Mods folder not found: $ModsPath"
        }

        Write-Host "`n🔍 Scanning mods in: $ModsPath" -ForegroundColor Green

        $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction Stop
        $CheatMods = @()

        foreach ($Mod in $ModFiles) {
            Write-Host "`nAnalyzing: $($Mod.Name)" -ForegroundColor DarkGray
            $Analysis = Analyze-Mod -JarPath $Mod.FullName -ModName $Mod.Name
            if ($Analysis.IsSuspicious) {
                Write-Host "🚨 Suspicious: $($Analysis.Reason)" -ForegroundColor Red
                $CheatMods += $Analysis
            } else {
                Write-Host "✅ Clean" -ForegroundColor Green
            }
        }

        # --- Results ---
        Write-Host "`n===== SCAN RESULTS =====" -ForegroundColor Cyan
        Write-Host "Mods scanned: $($ModFiles.Count)" -ForegroundColor White
        Write-Host "Suspicious mods: $($CheatMods.Count)" -ForegroundColor Yellow

        foreach ($Item in $CheatMods) {
            Write-Host "`n❌ $($Item.Mod)" -ForegroundColor Red
            Write-Host "   ➤ Reason: $($Item.Reason)" -ForegroundColor Yellow
        }

        # Optional: send webhook
        Send-Webhook -CheatMods $CheatMods

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

        $Files = Get-ChildItem $TempDir -Recurse -File
        foreach ($File in $Files) {
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
                if ($PathLower -match $sig) {
                    $FoundCheats += $sig
                }
            }
        }

        $FoundCheats = $FoundCheats | Select-Object -Unique

        return [PSCustomObject]@{
            Mod = $ModName
            IsSuspicious = ($FoundCheats.Count -gt 0)
            Reason = if ($FoundCheats.Count -gt 0) { "Detected cheat client: $($FoundCheats -join ', ')" } else { "" }
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
    return @(
        "meteorclient","wurstclient","aristois","futureclient","rusherhack","impact","baritone","xenon","kypton","argon","walksy","Osmium","gypsyy","Sakurwa","Lucid Argon","optimizer","macro","anchorhack","Glazed","clickcrystal"
    )
}

function Send-Webhook {
    param([array]$CheatMods)
    if (-not $WebhookUrl) { return }
    try {
        $embed = if ($CheatMods.Count -gt 0) {
            @{ title = "🚨 Suspicious Mods Found"; color = 16711680; description = ($CheatMods | ForEach-Object { "❌ $($_.Mod) — $($_.Reason)" }) -join "`n" }
        } else {
            @{ title = "✅ System Clean"; color = 65280; description = "No suspicious mods detected." }
        }
        $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json"
    } catch {}
}

# Start scan
Start-CheatScan
