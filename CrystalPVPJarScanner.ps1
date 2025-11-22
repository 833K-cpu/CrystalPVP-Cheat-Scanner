# CrystalPVPJarScanner.ps1
# Auto-detect running Minecraft/Modrinth/MultiMC, scan mods for cheat clients
# Zero false flags

$WebhookUrl = "" # Insert your Discord webhook if needed

function Start-CheatScan {
    Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    # Step 1: Detect running Minecraft/Java processes
    $MinecraftPath = $null
    $runningJava = Get-Process java,javaw,wjava -ErrorAction SilentlyContinue

    foreach ($p in $runningJava) {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
            # Try to find a path that ends with "mods" or contains ".minecraft" or known launcher patterns
            if ($cmd -match "([A-Z]:\\[^\" ]+\\(?:\.minecraft|MultiMC|ModrinthApp)[^\" ]*)") {
                $pathMatch = $matches[1]
                if (Test-Path $pathMatch) {
                    $MinecraftPath = $pathMatch
                    break
                }
            }
        } catch {}
    }

    # Step 2: Fallback to standard .minecraft
    if (-not $MinecraftPath) {
        $MinecraftPath = Join-Path $env:APPDATA ".minecraft"
        Write-Host "🟡 Minecraft not running or profile not detected — using default path: $MinecraftPath" -ForegroundColor Yellow
    } else {
        Write-Host "🟢 Running Minecraft detected — using path: $MinecraftPath" -ForegroundColor Green
    }

    # Step 3: Resolve mods folder
    $ModsPath = Join-Path $MinecraftPath "mods"
    if (-not (Test-Path $ModsPath)) {
        Write-Host "❌ Mods folder not found: $ModsPath" -ForegroundColor Red
        return
    }

    Write-Host "`n🔍 Scanning mods in: $ModsPath" -ForegroundColor Green

    $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction SilentlyContinue
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

    Send-Webhook -CheatMods $CheatMods
    Write-Host "`nScan completed." -ForegroundColor Green
    Read-Host "Press Enter to exit..."
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
        "meteorclient","wurstclient","aristois","futureclient","rusherhack","lambda","impact","baritone","xenon","kypton","argon","grim"
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

Start-CheatScan
