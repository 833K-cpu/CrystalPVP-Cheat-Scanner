# CrystalPVPJarScanner.ps1
# Zero False-Positive Minecraft Mod Scanner
# Detects only known cheat clients, ignores normal mods

# Optional Discord webhook
$WebhookUrl = ""  # Insert your Discord webhook here

function Start-CheatScan {
    try {
        Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
        Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

        # Step 1: Try to detect running Minecraft process (Modrinth, MultiMC, standard)
        $ModsPath = $null
        $runningMC = Get-Process java,javaw,wjava -ErrorAction SilentlyContinue

        foreach ($p in $runningMC) {
            try {
                $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
                # Modrinth profile
                if ($cmd -match "ModrinthApp\\profiles\\") {
                    $match = [regex]::Match($cmd, "(.*?\\profiles\\.*?)(\\s|$)")
                    if ($match.Success) {
                        $ModsPath = Join-Path $match.Groups[1].Value "mods"
                        break
                    }
                }
                # MultiMC instance
                elseif ($cmd -match "MultiMC\\instances\\") {
                    $match = [regex]::Match($cmd, "(.*?\\instances\\.*?)(\\s|$)")
                    if ($match.Success) {
                        $ModsPath = Join-Path $match.Groups[1].Value "mods"
                        break
                    }
                }
                # Standard .minecraft
                elseif ($cmd -match "\.minecraft") {
                    $match = [regex]::Match($cmd, "(.*?\\.minecraft)")
                    if ($match.Success) {
                        $ModsPath = Join-Path $match.Groups[1].Value "mods"
                        break
                    }
                }
            } catch {}
        }

        # Step 2: Fallback to default .minecraft if auto-detect failed
        if (-not $ModsPath -or -not (Test-Path $ModsPath)) {
            $DefaultPath = Join-Path $env:APPDATA ".minecraft\mods"
            if (Test-Path $DefaultPath) {
                $ModsPath = $DefaultPath
                Write-Host "🟡 Minecraft not running — using default path: $ModsPath" -ForegroundColor Yellow
            } else {
                # Step 3: Ask user
                Write-Host "Could not auto-detect running Minecraft. Please enter your mods folder path:"
                $ModsPath = Read-Host "Mods path"
            }
        }

        if (-not (Test-Path $ModsPath)) {
            throw "Mods folder not found: $ModsPath"
        }

        Write-Host "`n🔍 Scanning mods in: $ModsPath" -ForegroundColor Green

        # Scan mods
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

        # Results
        Write-Host "`n===== SCAN RESULTS =====" -ForegroundColor Cyan
        Write-Host "Mods scanned: $($ModFiles.Count)" -ForegroundColor White
        Write-Host "Suspicious mods: $($CheatMods.Count)" -ForegroundColor Yellow

        foreach ($Item in $CheatMods) {
            Write-Host "`n❌ $($Item.Mod)" -ForegroundColor Red
            Write-Host "   ➤ Reason: $($Item.Reason)" -ForegroundColor Yellow
        }

        # Optional webhook
        Send-Webhook -CheatMods $CheatMods

        Write-Host "`nScan completed." -ForegroundColor Green
        Read-Host "Press Enter to exit..."
    } catch {
        Write-Host "❌ Fatal error: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit..."
    }
}

function Analyze-Mod {
    param(
        [string]$JarPath,
        [string]$ModName
    )

    $TempDir = Join-Path $env:TEMP ("scan_" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $TempDir | Out-Null

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($JarPath, $TempDir)

        $CheatSignatures = Get-CheatSignatures
        $FoundCheats = @()

        $Files = Get-ChildItem $TempDir -Recurse -File
        foreach ($File in $Files) {
            # Check mod metadata
            if ($File.Name -match "fabric\.mod\.json|mcmod\.info") {
                try {
                    $Json = Get-Content $File.FullName -Raw | ConvertFrom-Json
                    if ($Json.id -and ($CheatSignatures -contains $Json.id.ToLower())) {
                        $FoundCheats += $Json.id
                    }
                } catch {}
            }

            # Check package/folder names
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
        "meteorclient",
        "wurstclient",
        "aristois",
        "futureclient",
        "rusherhack",
        "lambda",
        "impact",
        "baritone",
        "xenon"
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
        Write-Host "📨 Webhook sent." -ForegroundColor Green
    } catch {
        Write-Host "❌ Webhook error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Start scan
Start-CheatScan
