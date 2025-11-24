# CrystalPVPJarScanner - Real-time running Minecraft mod scanner
# Only flags truly suspicious mods
# Discord webhook integration with progress updates

$WebhookUrl = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S" # Replace with your webhook

function Start-CheatScan {
    try {
        Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
        Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

        $MinecraftPath = $null

        # --- Detect currently running Minecraft ---
        $javaProcesses = Get-Process java,javaw -ErrorAction SilentlyContinue
        foreach ($p in $javaProcesses) {
            try {
                $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
                if ($cmdLine -match "-gameDir\s+""?([^""\s]+)""?") {
                    $path = $matches[1]
                    if (Test-Path $path) {
                        $MinecraftPath = $path
                        break
                    }
                }
            } catch {}
        }

        if (-not $MinecraftPath) {
            Write-Host "❌ No running Minecraft instance found."
            return
        }

        $ModsPath = Join-Path $MinecraftPath "mods"
        if (-not (Test-Path $ModsPath)) {
            Write-Host "❌ Mods folder not found in running Minecraft path."
            return
        }

        $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction Stop
        $SuspiciousMods = @()
        $TotalMods = $ModFiles.Count
        $Counter = 0

        # --- Create initial webhook message ---
        $MessageId = Send-Webhook-Progress -Current 0 -Total $TotalMods

        foreach ($Mod in $ModFiles) {
            $Counter++
            # Update webhook with progress
            Send-Webhook-Progress -Current $Counter -Total $TotalMods -MessageId $MessageId

            $Analysis = Analyze-Mod -JarPath $Mod.FullName -ModName $Mod.Name
            if ($Analysis.IsSuspicious) {
                $SuspiciousMods += $Analysis
            }
        }

        # --- Send final webhook with flagged mods ---
        Send-Webhook-Final -CheatMods $SuspiciousMods

        Write-Host "`nScan completed." -ForegroundColor Green

    } catch {
        Write-Host "❌ Fatal error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Analyze-Mod {
    param([string]$JarPath, [string]$ModName)

    $TempDir = Join-Path $env:TEMP ("scan_" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $TempDir | Out-Null
    $FoundCheats = @()

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($JarPath, $TempDir)

        $CheatSignatures = @(
            "meteorclient","wurstclient","aristois","futureclient","rusherhack","impact","baritone","xenon"
        )

        $Files = Get-ChildItem $TempDir -Recurse -File
        foreach ($File in $Files) {
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
            Reason = if ($FoundCheats.Count -gt 0) { "Detected cheat package: $($FoundCheats -join ', ')" } else { "" }
        }

    } catch {
        return [PSCustomObject]@{
            Mod = $ModName
            IsSuspicious = $false
            Reason = "Scan error — may be protected or corrupted"
        }
    } finally {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Send-Webhook-Progress {
    param(
        [int]$Current,
        [int]$Total,
        [string]$MessageId = $null
    )
    if (-not $WebhookUrl) { return }

    $payload = @{
        content = "🔍 Analysing mods... [$Current / $Total]"
    } | ConvertTo-Json

    try {
        if ($MessageId) {
            # Edit previous message (optional)
            Invoke-RestMethod -Uri "$WebhookUrl/messages/$MessageId" -Method PATCH -Body $payload -ContentType "application/json"
        } else {
            $response = Invoke-RestMethod -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json"
            return $response.id
        }
    } catch {}
}

function Send-Webhook-Final {
    param([array]$CheatMods)
    if (-not $WebhookUrl) { return }

    if ($CheatMods.Count -eq 0) {
        $embed = @{ title="✅ No Suspicious Mods"; color=65280; description="All loaded mods are clean." }
    } else {
        $desc = ($CheatMods | ForEach-Object { "❌ $($_.Mod) — $($_.Reason)" }) -join "`n"
        $embed = @{ title="🚨 Suspicious Mods Found"; color=16711680; description=$desc }
    }

    $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 5

    try {
        Invoke-RestMethod -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json"
    } catch {}
}

# Start the scan
Start-CheatScan
