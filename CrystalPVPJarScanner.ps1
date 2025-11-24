# CrystalPVPJarScanner - Live Webhook + Running Minecraft Detection

$WebhookUrl = "YOUR_WEBHOOK_URL_HERE"
$WebhookMessageId = $null

function Start-CheatScan {
    try {
        Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
        Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

        # --- Detect running Minecraft ---
        $MinecraftPath = $null
        $javaProcesses = Get-Process java,javaw -ErrorAction SilentlyContinue
        foreach ($p in $javaProcesses) {
            try {
                $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
                if ($cmdLine) {
                    if ($cmdLine -match "-gameDir\s+""?([^""\s]+)""?") {
                        $path = $matches[1]
                        if (Test-Path $path) { $MinecraftPath = $path; break }
                    } elseif ($cmdLine -match "([a-zA-Z]:\\.*?\.minecraft)") {
                        $path = $matches[1]
                        if (Test-Path $path) { $MinecraftPath = $path; break }
                    }
                }
            } catch {}
        }

        if (-not $MinecraftPath) {
            Write-Host "❌ No running Minecraft detected. Exiting..." -ForegroundColor Red
            return
        }

        $ModsPath = Join-Path $MinecraftPath "mods"
        if (-not (Test-Path $ModsPath)) {
            Write-Host "❌ Mods folder not found: $ModsPath" -ForegroundColor Red
            return
        }

        $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar"
        $TotalMods = $ModFiles.Count
        $FlaggedMods = @()

        # --- Send initial webhook ---
        Send-InitialWebhook -TotalMods $TotalMods

        $Current = 0
        foreach ($Mod in $ModFiles) {
            $Current++
            $Analysis = Analyze-Mod -JarPath $Mod.FullName -ModName $Mod.Name
            if ($Analysis.IsSuspicious) { $FlaggedMods += $Analysis }

            # Update webhook live
            Update-Webhook -Current $Current -Total $TotalMods -CurrentMod $Mod.Name -FlaggedMods $FlaggedMods
        }

        # --- Send final results ---
        Send-FinalWebhook -FlaggedMods $FlaggedMods

        Write-Host "`nScan completed." -ForegroundColor Green
        Read-Host "Press Enter to exit..."

    } catch {
        Write-Host "❌ Fatal error: $($_.Exception.Message)" -ForegroundColor Red
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

        # --- Local file size check ---
        $LocalSizeMB = [math]::Round((Get-Item $JarPath).Length / 1MB, 2)
        $RemoteSizeMB = Get-ModrinthModSize -ModName $ModName
        $SizeDiff = if ($RemoteSizeMB -gt 0) { [math]::Round((($LocalSizeMB - $RemoteSizeMB)/$RemoteSizeMB)*100, 1) } else { 0 }

        if ($SizeDiff -ge 25) { $FoundCheats += "Size mismatch (local: ${LocalSizeMB}MB, Modrinth: ${RemoteSizeMB}MB, diff: ${SizeDiff}%)" }

        # --- Package / mod metadata check ---
        $Files = Get-ChildItem $TempDir -Recurse -File
        foreach ($File in $Files) {
            if ($File.Name -match "fabric\.mod\.json|mcmod\.info") {
                try {
                    $Json = Get-Content $File.FullName -Raw | ConvertFrom-Json
                    if ($Json.id -and ($CheatSignatures -contains $Json.id.ToLower())) {
                        $FoundCheats += "Known cheat client/package: $($Json.id)"
                    }
                } catch {}
            }
        }

        $FoundCheats = $FoundCheats | Select-Object -Unique

        return [PSCustomObject]@{
            Mod = $ModName
            IsSuspicious = ($FoundCheats.Count -gt 0)
            Reason = if ($FoundCheats.Count -gt 0) { $FoundCheats -join ", " } else { "" }
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
        "meteorclient","wurstclient","aristois","futureclient","rusherhack","impact","baritone","xenon","optimizer","glazed","clickcrystal"
    )
}

# --- Fake Modrinth API call (replace with real API if desired) ---
function Get-ModrinthModSize {
    param([string]$ModName)
    # For demo: return random size (MB) or 0 if unknown
    return Get-Random -Minimum 0 -Maximum 5
}

# --- Discord live webhook functions ---
function Send-InitialWebhook { param([int]$TotalMods)
    $embed = @{ title="CrystalPVPJarScanner"; color=16776960; description="🔍 Analysing mods... [0 / $TotalMods]`nCurrently analyzing: None" }
    $payload = @{ embeds=@($embed) } | ConvertTo-Json -Depth 5
    $response = Invoke-RestMethod -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json"
    $global:WebhookMessageId = $response.id
}

function Update-Webhook { param([int]$Current, [int]$Total, [string]$CurrentMod, [array]$FlaggedMods)
    $desc = "🔍 Analysing mods... [$Current / $Total]`nCurrently analyzing: $CurrentMod"
    if ($FlaggedMods.Count -gt 0) { $desc += "`n🚨 Flagged mods:`n" + ($FlaggedMods | ForEach-Object { "❌ $($_.Mod) — $($_.Reason)" }) -join "`n" }
    $embed = @{ title="CrystalPVPJarScanner"; color=16776960; description=$desc }
    $payload = @{ embeds=@($embed) } | ConvertTo-Json -Depth 5
    Invoke-RestMethod -Uri "$WebhookUrl/messages/$global:WebhookMessageId" -Method PATCH -Body $payload -ContentType "application/json"
}

function Send-FinalWebhook { param([array]$FlaggedMods)
    $desc = if ($FlaggedMods.Count -gt 0) { ($FlaggedMods | ForEach-Object { "❌ $($_.Mod) — $($_.Reason)" }) -join "`n" } else { "✅ No suspicious mods detected." }
    $embed = @{ title="CrystalPVPJarScanner - Scan Complete"; color=65280; description=$desc }
    $payload = @{ embeds=@($embed) } | ConvertTo-Json -Depth 5
    Invoke-RestMethod -Uri "$WebhookUrl/messages/$global:WebhookMessageId" -Method PATCH -Body $payload -ContentType "application/json"
}

# --- Start the scan ---
Start-CheatScan
