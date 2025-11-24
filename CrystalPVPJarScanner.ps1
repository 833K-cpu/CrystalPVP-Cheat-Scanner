# CrystalPVPJarScanner - Functional, English, safe webhook output
# Scans only the currently running Minecraft instance

$WebhookUrl = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S" # Optional

function Start-CheatScan {
    try {
        Write-Host "=== CrystalPVPJarScanner ===" -ForegroundColor Cyan
        Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

        $MinecraftPath = $null

        # --- Detect running Minecraft ---
        $javaProcesses = Get-Process java,javaw -ErrorAction SilentlyContinue
        foreach ($p in $javaProcesses) {
            try {
                $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
                if ($cmdLine -match "-gameDir\s+""?([^""\s]+)""?") {
                    $path = $matches[1]
                    if (Test-Path $path) { $MinecraftPath = $path; break }
                } elseif ($cmdLine -match "([a-zA-Z]:\\.*?\.minecraft)") {
                    $path = $matches[1]
                    if (Test-Path $path) { $MinecraftPath = $path; break }
                }
            } catch {}
        }

        if (-not $MinecraftPath) {
            Write-Host "❌ No running Minecraft detected. Exiting..."
            return
        }

        $ModsPath = Join-Path $MinecraftPath "mods"
        if (-not (Test-Path $ModsPath)) {
            Write-Host "❌ Mods folder not found in running instance: $ModsPath"
            return
        }

        $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction Stop
        $CheatMods = @()
        $Total = $ModFiles.Count
        $Index = 0

        # --- Initialize webhook message ---
        $webhookMessage = @{
            content = "🔍 Analysing mods... [ 0 / $Total ]"
        }
        $messageResponse = Invoke-RestMethod -Uri $WebhookUrl -Method POST -Body ($webhookMessage | ConvertTo-Json) -ContentType "application/json" | Out-Null

        # --- Scan mods ---
        foreach ($Mod in $ModFiles) {
            $Index++
            Write-Host "🔍 Analysing [$Index / $Total]: $($Mod.Name)" -ForegroundColor Cyan

            $Analysis = Analyze-Mod -JarPath $Mod.FullName -ModName $Mod.Name
            if ($Analysis.IsSuspicious) { $CheatMods += $Analysis }

            # --- Update webhook progress ---
            $update = @{ content = "🔍 Analysing mods... [ $Index / $Total ]" }
            Invoke-RestMethod -Uri $WebhookUrl -Method PATCH -Body ($update | ConvertTo-Json) -ContentType "application/json" | Out-Null
        }

        # --- Final results ---
        $ResultText = if ($CheatMods.Count -gt 0) {
            $CheatMods | ForEach-Object { "❌ $($_.Mod) — $($_.Reason)" } | Out-String
        } else { "✅ No suspicious mods detected." }

        $finalPayload = @{ content = "✅ Scan completed! `n$ResultText" }
        Invoke-RestMethod -Uri $WebhookUrl -Method PATCH -Body ($finalPayload | ConvertTo-Json) -ContentType "application/json" | Out-Null

        Write-Host "`nScan completed." -ForegroundColor Green

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

        $Files = Get-ChildItem $TempDir -Recurse -File
        foreach ($File in $Files) {
            if ($File.Name -match "fabric\.mod\.json|mcmod\.info") {
                try {
                    $Json = Get-Content $File.FullName -Raw | ConvertFrom-Json
                    if ($Json.id -and ($CheatSignatures -contains $Json.id.ToLower())) { $FoundCheats += $Json.id }
                } catch {}
            }
            $PathLower = $File.FullName.ToLower()
            foreach ($sig in $CheatSignatures) {
                if ($PathLower -match $sig) { $FoundCheats += $sig }
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
        "meteorclient","wurstclient","aristois","futureclient","rusherhack","impact",
        "baritone","xenon","kypton","argon","walksy","osmium","gypsyy","sakurwa",
        "lucid argon","optimizer","macro","anchorhack","glazed","clickcrystal"
    )
}

# Start the scan
Start-CheatScan
