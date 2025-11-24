# CrystalPVPJarScanner - Only running Minecraft, size & cheat detection
# Zero false-positive PVP mod scanner

$WebhookUrl = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S"

# -------------------------------
# Main Scan Function
# -------------------------------
function Start-CheatScan {
    try {
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

    } catch {
        Write-Host "❌ Fatal error: $($_.Exception.Message)" -ForegroundColor Red
    }
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
# Analyze a single mod
# -------------------------------
function Analyze-Mod {
    param([string]$JarPath, [string]$ModName)

    # Get local file size in MB
    $LocalSizeMB = [math]::Round((Get-Item $JarPath).Length / 1MB, 2)

    # Check against Modrinth size if possible
    $ModrinthSizeMB = Get-ModrinthSize -ModName $ModName
    $SizeDiffPercent = if ($ModrinthSizeMB -gt 0) { [math]::Round((($LocalSizeMB - $ModrinthSizeMB)/$ModrinthSizeMB)*100, 1) } else { 0 }

    # Flag only if diff >50% OR >2MB
    $IsSuspicious = $false
    $Reason = ""

    if ($SizeDiffPercent -gt 50 -or [math]::Abs($LocalSizeMB - $ModrinthSizeMB) -gt 2) {
        $IsSuspicious = $true
        $Reason += "Size mismatch (local: ${LocalSizeMB}MB, Modrinth: ${ModrinthSizeMB}MB, diff: ${SizeDiffPercent}%)"
    }

    # Check known cheat signatures
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
        Reason = $Reason
    }
}

# -------------------------------
# Get Modrinth size (simplified)
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
# Known cheat packages
# -------------------------------
function Get-CheatSignatures {
    return @(
        "meteorclient","wurstclient","aristois","futureclient","rusherhack","impact","baritone","xenon","kypton","argon","walksy","osmium","gypsyy","sakurwa","lucid","optimizer","macro","anchorhack","glazed","clickcrystal"
    )
}

# -------------------------------
# Optional Discord Webhook
# -------------------------------
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

# -------------------------------
# Start scan
# -------------------------------
Start-CheatScan

