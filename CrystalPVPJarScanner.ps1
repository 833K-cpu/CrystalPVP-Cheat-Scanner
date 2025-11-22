# Minecraft Screenshare Scanner - Advanced Webhook Version
function Start-CheatScan {
    Write-Host "=== MINECRAFT SCREENSHARE SCANNER ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    # Webhook URL fest eingebaut
    $WebhookUrl = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S"

    # Auto-detect all Minecraft paths
    $DetectedPaths = @()
    
    # Standard paths
    $pathsToCheck = @(
        "$env:APPDATA\.minecraft",
        "$env:USERPROFILE\AppData\Roaming\.minecraft"
    )
    
    # Modrinth profiles
    $modrinthPath = "$env:APPDATA\ModrinthApp\profiles"
    if (Test-Path $modrinthPath) {
        $modrinthProfiles = Get-ChildItem $modrinthPath -Directory -ErrorAction SilentlyContinue
        foreach ($profile in $modrinthProfiles) {
            $pathsToCheck += $profile.FullName
        }
    }
    
    # Check all paths
    foreach ($path in $pathsToCheck) {
        if (Test-Path $path) {
            $DetectedPaths += $path
        }
    }
    
    if ($DetectedPaths.Count -eq 0) {
        Write-Host "❌ No Minecraft folders found automatically!" -ForegroundColor Red
        Write-Host "Please enter path manually:" -ForegroundColor Yellow
        $MinecraftPath = Read-Host "Minecraft folder path"
    }
    elseif ($DetectedPaths.Count -eq 1) {
        $MinecraftPath = $DetectedPaths[0]
        Write-Host "✅ Auto-selected: $MinecraftPath" -ForegroundColor Green
    }
    else {
        Write-Host "`n📁 Multiple Minecraft folders found:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $DetectedPaths.Count; $i++) {
            Write-Host "  $($i+1). $($DetectedPaths[$i])" -ForegroundColor Gray
        }
        $choice = Read-Host "`nSelect folder (1-$($DetectedPaths.Count))"
        if ($choice -match "^\d+$" -and [int]$choice -le $DetectedPaths.Count) {
            $MinecraftPath = $DetectedPaths[[int]$choice - 1]
        } else {
            $MinecraftPath = $DetectedPaths[0]
        }
    }

    $MinecraftPath = $MinecraftPath.Trim().Trim('"')

    if (-not (Test-Path $MinecraftPath)) {
        Write-Host "❌ Path does not exist: $MinecraftPath" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    Write-Host "`n🔍 Scanning: $MinecraftPath" -ForegroundColor Green

    # Known cheat signatures - Dateiinhalte und Hashes
    $CheatSignatures = @(
        # Meteor Client
        @{ 
            Name = "Meteor Client"
            FileHashes = @("A1B2C3D4E5F678901234567890123456", "FEDCBA98765432109876543210987654")
            FilePatterns = @("meteor", "minegame159", "meteor-client")
            ClassPatterns = @("meteor", "minegame159")
            SizeRange = @(5000000, 10000000) # 5-10MB
        },
        
        # Wurst Client
        @{
            Name = "Wurst Client"
            FileHashes = @("WURST_HASH_123456789", "WURST_HASH_987654321")
            FilePatterns = @("wurst", "wurstclient")
            ClassPatterns = @("wurst", "net.wurst")
            SizeRange = @(3000000, 8000000) # 3-8MB
        },
        
        # LiquidBounce
        @{
            Name = "LiquidBounce"
            FileHashes = @("LIQUIDBOUNCE_HASH_123", "LIQUIDBOUNCE_HASH_456")
            FilePatterns = @("liquidbounce", "liquidbounceplus")
            ClassPatterns = @("ccbluex", "liquidbounce")
            SizeRange = @(2000000, 6000000) # 2-6MB
        },
        
        # RusherHack
        @{
            Name = "RusherHack"
            FileHashes = @("RUSHERHACK_HASH_123")
            FilePatterns = @("rusherhack", "rusherhack2")
            ClassPatterns = @("rusherhack", "rusherhack2")
            SizeRange = @(4000000, 9000000) # 4-9MB
        },
        
        # Future Client
        @{
            Name = "Future Client"
            FileHashes = @("FUTURE_HASH_123456")
            FilePatterns = @("future", "futureclient")
            ClassPatterns = @("future", "client.future")
            SizeRange = @(8000000, 15000000) # 8-15MB
        },
        
        # Sigma Client
        @{
            Name = "Sigma Client"
            FileHashes = @("SIGMA_HASH_123456")
            FilePatterns = @("sigma", "sigmaclient")
            ClassPatterns = @("sigma", "sigmaclient")
            SizeRange = @(10000000, 20000000) # 10-20MB
        }
    )

    # Suspicious patterns in file contents
    $SuspiciousPatterns = @(
        "killaura", "reach", "velocity", "noslow", "scaffold", "autoclicker",
        "antiknockback", "nohunger", "nofall", "speedmine", "xray", "baritone",
        "crystalaura", "anchoraura", "antibot", "esp", "nametags", "tracers"
    )

    $ModsPath = "$MinecraftPath\mods"
    
    if (-not (Test-Path $ModsPath)) {
        Write-Host "❌ No 'mods' folder found!" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    Write-Host "`n🕵️ Advanced scanning for cheat mods..." -ForegroundColor Green
    Write-Host "   This may take a while for large mod folders..." -ForegroundColor Yellow
    
    $TotalMods = 0
    $CheatModsFound = 0
    $CheatModsList = @()
    $ComputerName = $env:COMPUTERNAME
    $UserName = $env:USERNAME

    try {
        $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction Stop
    } catch {
        Write-Host "❌ Error accessing mods folder: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    # Load common legitimate mod hashes (könnte erweitert werden)
    $LegitimateModHashes = @{
        "fabric-api" = @("common_fabric_api_hash")
        "sodium" = @("common_sodium_hash")
        "optifine" = @("common_optifine_hash")
        "litematica" = @("common_litematica_hash")
    }

    foreach ($Mod in $ModFiles) {
        $TotalMods++
        $ModName = $Mod.Name
        $ModPath = $Mod.FullName
        
        Write-Host "  Scanning: $ModName" -ForegroundColor Gray
        
        # Calculate file hash
        $FileHash = Get-FileHash -Path $ModPath -Algorithm MD5 | Select-Object -ExpandProperty Hash
        
        # Check file size
        $FileSize = $Mod.Length
        
        # Advanced detection methods
        $DetectionResults = @()
        
        # Method 1: Check against known cheat signatures
        foreach ($Signature in $CheatSignatures) {
            # Check file size range
            if ($FileSize -ge $Signature.SizeRange[0] -and $FileSize -le $Signature.SizeRange[1]) {
                # Check filename patterns
                foreach ($Pattern in $Signature.FilePatterns) {
                    if ($ModName -match $Pattern) {
                        $DetectionResults += "$($Signature.Name) (Filename)"
                    }
                }
                
                # Check file hashes (wenn wir die echten Hashes hätten)
                foreach ($Hash in $Signature.FileHashes) {
                    if ($FileHash -eq $Hash) {
                        $DetectionResults += "$($Signature.Name) (Hash)"
                    }
                }
            }
        }
        
        # Method 2: Analyze JAR contents for suspicious patterns
        $SuspiciousContentFound = Analyze-JarContent -JarPath $ModPath -Patterns $SuspiciousPatterns
        if ($SuspiciousContentFound.Count -gt 0) {
            $DetectionResults += "Suspicious content: $($SuspiciousContentFound -join ', ')"
        }
        
        # Method 3: Check for obfuscated/renamed files
        if (Test-SuspiciousFile -FilePath $ModPath -FileName $ModName -FileSize $FileSize) {
            $DetectionResults += "Suspicious file characteristics"
        }
        
        # Method 4: Check if file is in legitimate mods list
        $IsLegitimate = $false
        foreach ($LegitMod in $LegitimateModHashes.GetEnumerator()) {
            foreach ($LegitHash in $LegitMod.Value) {
                if ($FileHash -eq $LegitHash) {
                    $IsLegitimate = $true
                    break
                }
            }
            if ($IsLegitimate) { break }
        }
        
        if (-not $IsLegitimate -and $DetectionResults.Count -gt 0) {
            $CheatModsFound++
            $ModInfo = @{
                Name = $ModName
                FilePath = $ModPath
                FileSize = "$([math]::Round($Mod.Length/1KB, 2)) KB"
                FileSizeMB = [math]::Round($Mod.Length/1MB, 2)
                CheatTypes = $DetectionResults -join "; "
                Hash = $FileHash
                LastModified = $Mod.LastWriteTime
                DetectionMethods = $DetectionResults.Count
            }
            $CheatModsList += $ModInfo
            
            Write-Host "    🚨 SUSPICIOUS: $($DetectionResults -join ', ')" -ForegroundColor Red
        } else {
            Write-Host "    ✅ Clean" -ForegroundColor Green
        }
    }

    # Display results
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "SCREENSHARE SCAN RESULTS" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan
    
    Write-Host "📊 JAR files scanned: $TotalMods" -ForegroundColor White
    
    if ($CheatModsFound -gt 0) {
        Write-Host "🚨 SUSPICIOUS MODS FOUND: $CheatModsFound" -ForegroundColor Red
        
        foreach ($CheatMod in $CheatModsList) {
            Write-Host "`n❌ $($CheatMod.Name)" -ForegroundColor Red
            Write-Host "   📁 Detection: $($CheatMod.CheatTypes)" -ForegroundColor Yellow
            Write-Host "   📦 Size: $($CheatMod.FileSize)" -ForegroundColor Gray
            Write-Host "   🔍 Methods: $($CheatMod.DetectionMethods)" -ForegroundColor Cyan
        }

        # Sende Ergebnisse an Webhook
        Send-WebhookResults -CheatModsList $CheatModsList -ComputerName $ComputerName -UserName $UserName -TotalMods $TotalMods -WebhookUrl $WebhookUrl
        
        Write-Host "`n📋 Suspicious files:" -ForegroundColor Yellow
        foreach ($CheatMod in $CheatModsList) {
            Write-Host "   • $($CheatMod.Name) ($($CheatMod.CheatTypes))" -ForegroundColor White
        }
        
    } else {
        Write-Host "`n✅ NO SUSPICIOUS MODS DETECTED!" -ForegroundColor Green
        Write-Host "System appears clean." -ForegroundColor Green
        
        # Sende auch "clean" Ergebnis an Webhook
        Send-WebhookResults -CheatModsList @() -ComputerName $ComputerName -UserName $UserName -TotalMods $TotalMods -WebhookUrl $WebhookUrl
    }

    Write-Host "`nScan completed: $(Get-Date)" -ForegroundColor Yellow
    Write-Host "Press Enter to exit..." -ForegroundColor Gray
    Read-Host
}

function Analyze-JarContent {
    param(
        [string]$JarPath,
        [array]$Patterns
    )
    
    $FoundPatterns = @()
    
    try {
        # Temporäres Verzeichnis für JAR-Extraktion
        $TempDir = Join-Path $env:TEMP "jar_analysis_$(Get-Random)"
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
        
        # Extrahiere JAR-Inhalt
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($JarPath, $TempDir)
        
        # Durchsuche alle Dateien im JAR
        $AllFiles = Get-ChildItem $TempDir -Recurse -File | Where-Object {
            $_.Extension -in @('.class', '.java', '.txt', '.json', '.mcmeta') -or
            $_.Name -eq 'fabric.mod.json' -or
            $_.Name -eq 'mods.toml'
        }
        
        foreach ($File in $AllFiles) {
            try {
                $Content = Get-Content $File.FullName -Raw -ErrorAction Stop
                if ($Content) {
                    foreach ($Pattern in $Patterns) {
                        if ($Content -match $Pattern) {
                            $FoundPatterns += $Pattern
                        }
                    }
                }
            } catch {
                # Kann nicht gelesen werden, überspringen
            }
        }
        
        # Räume auf
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        
    } catch {
        # Fehler bei Extraktion, wahrscheinlich keine JAR oder korrupt
    }
    
    return $FoundPatterns | Select-Object -Unique
}

function Test-SuspiciousFile {
    param(
        [string]$FilePath,
        [string]$FileName,
        [long]$FileSize
    )
    
    $Suspicious = $false
    
    # Sehr kleine oder sehr große Dateien
    if ($FileSize -lt 1000 -or $FileSize -gt 50000000) { # <1KB oder >50MB
        $Suspicious = $true
    }
    
    # Generische Namen die verdächtig sein könnten
    $GenericNames = @(
        "mod.jar", "client.jar", "hack.jar", "cheat.jar", 
        "utility.jar", "optimizer.jar", "tool.jar"
    )
    
    if ($GenericNames -contains $FileName.ToLower()) {
        $Suspicious = $true
    }
    
    # Namen die nur aus Zufallszeichen bestehen
    if ($FileName -match "^[a-z0-9]{8,}\.jar$") {
        $Suspicious = $true
    }
    
    return $Suspicious
}

function Send-WebhookResults {
    param(
        [array]$CheatModsList,
        [string]$ComputerName,
        [string]$UserName,
        [int]$TotalMods,
        [string]$WebhookUrl
    )

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        if ($CheatModsList.Count -gt 0) {
            # Erstelle Embed für gefundene Cheats
            $description = "**Advanced Scan Results for $UserName@$ComputerName**`n"
            $description += "**Time:** $timestamp`n"
            $description += "**Total Mods Scanned:** $TotalMods`n"
            $description += "**Suspicious Mods Found:** $($CheatModsList.Count)`n`n"
            
            foreach ($mod in $CheatModsList) {
                $description += "🔴 **$($mod.Name)**`n"
                $description += "   Detection: $($mod.CheatTypes)`n"
                $description += "   Size: $($mod.FileSize)`n"
                $description += "   Hash: $($mod.Hash)`n`n"
            }
            
            $color = 16711680  # Rot
            $title = "🚨 SUSPICIOUS MODS DETECTED"
        } else {
            # Erstelle Embed für sauberen Scan
            $description = "**Advanced Scan Results for $UserName@$ComputerName**`n"
            $description += "**Time:** $timestamp`n"
            $description += "**Total Mods Scanned:** $TotalMods`n"
            $description += "**Suspicious Mods Found:** 0`n`n"
            $description += "✅ **System appears clean**"
            
            $color = 65280  # Grün
            $title = "✅ ADVANCED SCAN COMPLETED - CLEAN"
        }

        $embed = @{
            title = $title
            description = $description
            color = $color
            timestamp = $timestamp
        }

        $payload = @{
            embeds = @($embed)
        } | ConvertTo-Json -Depth 10

        $headers = @{
            "Content-Type" = "application/json"
        }

        # Sende Webhook
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload -Headers $headers
        Write-Host "✅ Results sent to webhook" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Error sending webhook: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Start scan
Start-CheatScan
