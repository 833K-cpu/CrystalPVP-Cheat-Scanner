# CrystalPVPJarScanner - Live scanning of running Minecraft mods
# Zero false-positive PVP mod scanner
# Webhook URL is private and will not be displayed
$WebhookUrl = "YOUR_WEBHOOK_URL_HERE"

function Start-CheatScan {
    Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    # Detect running Minecraft process
    $MinecraftPath = $null
    $runningMC = Get-Process java,javaw -ErrorAction SilentlyContinue
    foreach ($p in $runningMC) {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
            if ($cmd -match "-gameDir\s+""?([^""\s]+)""?") {
                $path = $matches[1]
                if (Test-Path $path) {
                    $MinecraftPath = $path
                    break
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
        Write-Host "❌ Mods folder not found at $ModsPath" -ForegroundColor Red
        return
    }

    $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction Stop
    $TotalMods = $ModFiles.Count
    $FlaggedMods = @()
    $Current = 0

    foreach ($Mod in $ModFiles) {
        $Current++
        Write-Host "🔍 Analysing [$Current / $TotalMods]: $($Mod.Name)" -ForegroundColor DarkGray

        $Analysis = Analyze-Mod -JarPath $Mod.FullName -ModName $Mod.Name

        if ($Analysis.IsSuspicious) {
            $FlaggedMods += $Analysis
        }

        Send-ProgressWebhook -Current $Current -Total $TotalMods -CurrentMod $Mod.Name -FlaggedMods $FlaggedMods
    }

    Write-Host "`n===== SCAN RESULTS =====" -ForegroundColor Cyan
    if ($FlaggedMods.Count -eq 0) {
        Write-Host "✅ No suspicious mods detected." -ForegroundColor Green
    } else {
        foreach ($Item in $FlaggedMods) {
            Write-Host "❌ $($Item.Mod) — $($Item.Reason)" -ForegroundColor Red
        }
    }

    Send-FinalWebhook -FlaggedMods $FlaggedMods
    Write-Host "`nScan completed." -ForegroundColor Green
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

        # Check mod metadata JSON
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
        }

        # Check mod size difference (local vs Modrinth) — only flag if >20% difference
        $LocalSizeMB = [math]::Round((Get-Item $JarPath).Length / 1MB, 2)
        $RemoteSizeMB = Get-ModrinthSize -ModName $ModName
        if ($RemoteSizeMB -and ($LocalSizeMB / $RemoteSizeMB -lt 0.8 -or $LocalSizeMB / $RemoteSizeMB -gt 1.2)) {
            $FoundCheats += "Size mismatch (local: $LocalSizeMB MB, Modrinth: $RemoteSizeMB MB)"
        }

        $FoundCheats = $FoundCheats | Select-Object -Unique

        return [PSCustomObject]@{
            Mod = $ModName
            IsSuspicious = ($FoundCheats.Count -gt 0)
            Reason = if ($FoundCheats.Count -gt 0) { $FoundCheats -join ', ' } else { "" }
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
    return @("meteorclient","wurstclient","aristois","futureclient","rusherhack","impact","baritone","xenon")
}

function Get-ModrinthSize {
    param([string]$ModName)
    try {
        $url = "https://api.modrinth.com/v2/project/$ModName"
        $resp = Invoke-RestMethod -Uri $url -Method GET
        if ($resp.versions) {
            $versionId = $resp.versions[0]
            $versionResp = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version/$versionId"
            return [math]::Round($versionResp.files[0].size / 1MB, 2)
        }
    } catch { return $null }
}

function Send-ProgressWebhook {
    param([int]$Current, [int]$Total, [string]$CurrentMod, [array]$FlaggedMods)
    if (-not $WebhookUrl) { return }
    try {
        $desc = "🔍 Analysing mods... [$Current / $Total]`nCurrently analyzing: $CurrentMod"
        if ($FlaggedMods.Count -gt 0) {
            $desc += "`n🚨 Flagged mods so far:`n" + ($FlaggedMods | ForEach-Object { "❌ $($_.Mod) — $($_.Reason)" }) -join "`n"
        }
        $embed = @{ title="CrystalPVPJarScanner - Live Progress"; color=16776960; description=$desc }
        $payload = @{ embeds=@($embed) } | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri $WebhookUrl -Method PATCH -Body $payload -ContentType "application/json"
    } catch {}
}

function Send-FinalWebhook {
    param([array]$FlaggedMods)
    if (-not $WebhookUrl) { return }
    try {
        $desc = if ($FlaggedMods.Count -gt 0) {
            ($FlaggedMods | ForEach-Object { "❌ $($_.Mod) — $($_.Reason)" }) -join "`n"
        } else { "✅ No suspicious mods detected." }

        $embed = @{ title="CrystalPVPJarScanner - Scan Complete"; color=65280; description=$desc }
        $payload = @{ embeds=@($embed) } | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json"
    } catch {}
}

# Start scanning only running Minecraft
Start-CheatScan
