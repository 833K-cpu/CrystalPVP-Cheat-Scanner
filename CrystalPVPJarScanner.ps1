# CrystalPVPJarScanner.ps1
# Zero False-Positive Minecraft Mod Scanner
# Auto-detects running Minecraft launcher or common launcher folders

# Optional Discord webhook
$WebhookUrl = ""  # <-- Insert your webhook here if needed

function Start-CheatScan {
    try {
        Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
        Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

        # --- 1) Auto-detect Minecraft/Launcher paths ---
        $MinecraftPath = $null
        $PossiblePaths = @()

        # Vanilla
        $PossiblePaths += Join-Path $env:APPDATA ".minecraft"

        # Modrinth
        $modrinthBase = Join-Path $env:APPDATA "ModrinthApp\profiles"
        if (Test-Path $modrinthBase) { 
            $PossiblePaths += Get-ChildItem $modrinthBase -Directory | ForEach-Object { $_.FullName } 
        }

        # MultiMC (Desktop default)
        $multiMCBase = Join-Path $env:USERPROFILE "Desktop\MultiMC\instances"
        if (Test-Path $multiMCBase) { 
            $PossiblePaths += Get-ChildItem $multiMCBase -Directory | ForEach-Object { $_.FullName } 
        }

        # Lunar
        $lunarBase = Join-Path $env:APPDATA ".lunarclient\offline"
        if (Test-Path $lunarBase) { 
            $PossiblePaths += Get-ChildItem $lunarBase -Directory | ForEach-Object { $_.FullName } 
        }

        # Badlion
        $badlionBase = Join-Path $env:APPDATA ".badlionclient\.minecraft"
        if (Test-Path $badlionBase) { $PossiblePaths += $badlionBase }

        # Use the first path that has a mods folder
        foreach ($path in $PossiblePaths) {
            $mods = Join-Path $path "mods"
            if (Test-Path $mods) {
                $MinecraftPath = $path
                break
            }
        }

        if (-not $MinecraftPath) {
            Write-Host "❌ Could not auto-detect any Minecraft profile." -ForegroundColor Red
            Read-Host "Please press Enter to exit..."
            return
        }

        $ModsPath = Join-Path $MinecraftPath "mods"
        Write-Host "🟢 Minecraft profile detected: $MinecraftPath" -ForegroundColor Green
        Write-Host "🔍 Scanning mods in: $ModsPath" -ForegroundColor Yellow

        # --- 2) Scan mods ---
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

        # --- 3) Results ---
        Write-Host "`n===== SCAN RESULTS =====" -ForegroundColor Cyan
        Write-Host "Mods scanned: $($ModFiles.Count)" -ForegroundColor White
        Write-Host "Suspicious mods: $($CheatMods.Count)" -ForegroundColor Yellow

        foreach ($Item in $CheatMods) {
            Write-Host "`n❌ $($Item.Mod)" -ForegroundColor Red
            Write-Host "   ➤ Reason: $($Item.Reason)" -ForegroundColor Yellow
        }

        # --- 4) Optional webhook ---
        Send-Webhook -CheatMods $CheatMods

        Write-Host "`nScan completed." -ForegroundColor Green
        Read-Host "Press Enter to exit..."
    }
    catch {
        Write-Host "❌ Fatal error: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit..."
    }
}

# --- Analyze a single mod ---
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
    }
    catch {
        return [PSCustomObject]@{
            Mod = $ModName
            IsSuspicious = $false
            Reason = "Scan error — file may be protected or corrupted"
        }
    }
    finally {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Known cheat client IDs ---
function Get-CheatSignatures {
    return @(
        "meteorclient", "wurstclient", "aristois", "futureclient",
        "rusherhack", "lambda", "impact", "baritone", "xenon",
        "kypton", "argon", "grim"
    )
}

# --- Optional webhook sender ---
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

# --- Start scan ---
Start-CheatScan
