# CrystalPVPJarScanner - Live Discord progress updates

$WebhookUrl = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S"

# -------------------------------
# Start scan
# -------------------------------
function Start-CheatScan {
    Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    $MinecraftPath = Get-RunningMinecraftPath
    if (-not $MinecraftPath) {
        Write-Host "❌ No running Minecraft instance detected. Scanner stopped." -ForegroundColor Red
        return
    }

    $ModsPath = Join-Path $MinecraftPath "mods"
    if (-not (Test-Path $ModsPath)) {
        Write-Host "❌ Mods folder not found: $ModsPath" -ForegroundColor Red
        return
    }

    $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction Stop
    $AllMods = @()
    $totalMods = $ModFiles.Count
    $current = 0

    # Send initial webhook
    Send-ProgressWebhook -Current $current -Total $totalMods -CurrentMod "Starting scan..." -FlaggedMods @()

    foreach ($Mod in $ModFiles) {
        $current++
        Write-Host "Analysing mods... [ $current / $totalMods ] $($Mod.Name)" -ForegroundColor DarkGray
        $Analysis = Analyze-Mod -JarPath $Mod.FullName -ModName $Mod.Name
        $AllMods += $Analysis

        # Update webhook live
        $FlaggedModsSoFar = $AllMods | Where-Object { $_.IsSuspicious }
        Send-ProgressWebhook -Current $current -Total $totalMods -CurrentMod $Mod.Name -FlaggedMods $FlaggedModsSoFar
    }

    # Final results
    $FlaggedMods = $AllMods | Where-Object { $_.IsSuspicious }

    Write-Host "`n===== SCAN RESULTS =====" -ForegroundColor Cyan
    if ($FlaggedMods.Count -eq 0) {
        Write-Host "✅ No suspicious mods detected." -ForegroundColor Green
    } else {
        foreach ($Item in $FlaggedMods) {
            Write-Host "❌ $($Item.Mod) — $($Item.Reason)" -ForegroundColor Red
        }
    }

    # Final webhook
    Send-FinalWebhook -FlaggedMods $FlaggedMods -TotalMods $totalMods

    Write-Host "`nScan completed." -ForegroundColor Green
}

# -------------------------------
# Live webhook updates during scan
# -------------------------------
function Send-ProgressWebhook {
    param(
        [int]$Current,
        [int]$Total,
        [string]$CurrentMod,
        [array]$FlaggedMods
    )
    if (-not $WebhookUrl) { return }

    try {
        $desc = "🔍 Scanning mods... [$Current / $Total]`nCurrently analyzing: $CurrentMod"
        if ($FlaggedMods.Count -gt 0) {
            $desc += "`n🚨 Flagged mods so far:`n" + ($FlaggedMods | ForEach-Object { "❌ $($_.Mod) — $($_.Reason)" }) -join "`n"
        }

        $embed = @{
            title = "CrystalPVPJarScanner - Live Progress"
            color = 16776960 # yellow
            description = $desc
        }

        $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri $WebhookUrl -Method PATCH -Body $payload -ContentType "application/json"
    } catch {}
}

# -------------------------------
# Final webhook after scan
# -------------------------------
function Send-FinalWebhook {
    param(
        [array]$FlaggedMods,
        [int]$TotalMods
    )
    if (-not $WebhookUrl) { return }

    try {
        $desc = if ($FlaggedMods.Count -eq 0) {
            "✅ All $TotalMods mods scanned. No suspicious mods detected."
        } else {
            "🚨 Suspicious mods detected ($($FlaggedMods.Count) of $TotalMods):`n" +
            ($FlaggedMods | ForEach-Object { "❌ $($_.Mod) — $($_.Reason)" }) -join "`n"
        }

        $embed = @{
            title = "CrystalPVPJarScanner - Scan Completed"
            color = if ($FlaggedMods.Count -eq 0) { 65280 } else { 16711680 }
            description = $desc
        }

        $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json"
    } catch {}
}

# -------------------------------
# Detect running Minecraft folder
# -------------------------------
function Get-RunningMinecraftPath {
    $javaProcesses = Get-Process java,javaw -ErrorAction SilentlyContinue
    foreach ($p in $javaProcesses) {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
            if ($cmdLine -match "-gameDir\s+""?([^""\s]+)""?") {
                $path = $matches[1]
                if (Test-Path $path) { return $path }
            }
        } catch {}
    }
    return $null
}

# -------------------------------
# Analyze single mod
# -------------------------------
function Analyze-Mod {
    param([string]$JarPath, [string]$ModName)

    $LocalSizeMB = [math]::Round((Get-Item $JarPath).Length / 1MB, 2)
    $ModrinthSizeMB = Get-ModrinthSize -ModName $ModName
    $SizeDiffPercent = if ($ModrinthSizeMB -gt 0) { [math]::Round((($LocalSizeMB - $ModrinthSizeMB)/$ModrinthSizeMB)*100, 1) } else { 0 }

    $IsSuspicious = $false
    $Reason = ""

    if ($SizeDiffPercent -gt 50 -or [math]::Abs($LocalSizeMB - $ModrinthSizeMB) -gt 2) {
        $IsSuspicious = $true
        $Reason += "Size mismatch (local: ${LocalSizeMB}MB, Modrinth: ${ModrinthSizeMB}MB, diff: ${SizeDiffPercent}%)"
    }

    $CheatSignatures = Get-CheatSignatures
    foreach ($sig in $CheatSignatures) {
        if ($ModName.ToLower() -match $sig) {
            $IsSuspicious = $true
            if ($Reason) { $Reason += " | " }
            $Reason += "Known cheat client/package: $sig"
        }
    }

    return [PSCustomObject]@{
        Mod = $ModName
        IsSuspicious = $IsSuspicious
        Reason = if ($IsSuspicious) { $Reason } else { "Clean" }
    }
}

# -------------------------------
# Modrinth size check
# -------------------------------
function Get-ModrinthSize {
    param([string]$ModName)
    try {
        $slug = $ModName.ToLower() -replace "[^a-z0-9\-]","-"
        $apiUrl = "https://api.modrinth.com/v2/project/$slug"
        $resp = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
        if ($resp.versions -and $resp.versions.Count -gt 0) {
            $versionId = $resp.versions[0]
            $versionData = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version/$versionId"
            return [math]::Round(($versionData.files[0].size / 1MB), 2)
        }
    } catch {}
    return 0
}

# -------------------------------
# Cheat signatures
# -------------------------------
function Get-CheatSignatures {
    return @(
        "meteorclient","wurstclient","aristois","futureclient","rusherhack","impact","baritone","xenon","kypton","argon","walksy","osmium","gypsyy","sakurwa","lucid","optimizer","macro","anchorhack","glazed","clickcrystal"
    )
}

# -------------------------------
# Start scanning
# -------------------------------
Start-CheatScan
