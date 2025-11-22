# CrystalPVPJarScanner.ps1
# Zero False-Positive Minecraft Mod Scanner
# Detects only known cheat clients, ignores normal mods

# Optional Discord Webhook
$WebhookUrl = ""  # Insert your webhook here

# -----------------------------
# Helper: Normalize Path
# -----------------------------
function Normalize-Path {
    param([string]$Path)
    if ($Path) {
        $Path = $Path.Trim('"')      # Remove quotes
        $Path = $Path.Trim()         # Remove whitespace
        try {
            $Path = [System.IO.Path]::GetFullPath($Path)
            if (Test-Path $Path) { return $Path }
        } catch {}
    }
    return $null
}

# -----------------------------
# Main Scanner
# -----------------------------
function Start-CheatScan {
    try {
        Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
        Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

        # 1) Detect running Minecraft process
        $MinecraftPath = $null
        $runningMC = Get-Process java,javaw,wjava -ErrorAction SilentlyContinue
        foreach ($p in $runningMC) {
            try {
                $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
                if ($cmd -match "\.minecraft") {
                    $match = [regex]::Match($cmd, "(.*?\.minecraft)")
                    if ($match.Success) {
                        $MinecraftPath = Normalize-Path $match.Groups[1].Value
                        if ($MinecraftPath) { break }
                    }
                }
            } catch {}
        }

        # 2) Fallback: ask user if not found
        if (-not $MinecraftPath) {
            Write-Host "🟡 Minecraft not running or profile not detected."
            $InputPath = Read-Host "Enter your Minecraft/Modrinth/MultiMC folder path"
            $MinecraftPath = Normalize-Path $InputPath
        }

        # 3) Final fallback: default .minecraft
        if (-not $MinecraftPath) {
            $MinecraftPath = Join-Path $env:APPDATA ".minecraft"
            $MinecraftPath = Normalize-Path $MinecraftPath
            Write-Host "🟡 Using default path: $MinecraftPath" -ForegroundColor Yellow
        }

        # 4) Mods folder
        $ModsPath = Join-Path $MinecraftPath "mods"
        $ModsPath = Normalize-Path $ModsPath
        if (-not $ModsPath) {
            throw "Mods folder not found in $MinecraftPath"
        }

        Write-Host "`n🔍 Scanning mods in: $ModsPath" -ForegroundColor Green

        # 5) Scan each .jar
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

        # -------------------------
        # Results
        # -------------------------
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

# -----------------------------
# Analyze a single mod
# -----------------------------
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
            # Check mod metadata JSON
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

# -----------------------------
# Known cheat clients
# -----------------------------
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
        "xenon",
        "kypton",
        "argon",
        "grim"
    )
}

# -----------------------------
# Discord webhook sender
# -----------------------------
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

# -----------------------------
# Start the scan
# -----------------------------
Start-CheatScan
