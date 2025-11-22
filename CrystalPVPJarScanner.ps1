# Minecraft Screenshare Scanner - Advanced Content Analysis
function Start-CheatScan {
    Write-Host "=== MINECRAFT SCREENSHARE SCANNER ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    # Webhook URL
    $WebhookUrl = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S"

    # Auto-detect Minecraft path
    $MinecraftPath = "$env:APPDATA\.minecraft"
    if (-not (Test-Path $MinecraftPath)) {
        Write-Host "❌ Default Minecraft path not found!" -ForegroundColor Red
        Write-Host "Please enter Minecraft folder path:" -ForegroundColor Yellow
        $MinecraftPath = Read-Host "Path"
    }

    $MinecraftPath = $MinecraftPath.Trim().Trim('"')

    if (-not (Test-Path $MinecraftPath)) {
        Write-Host "❌ Path does not exist: $MinecraftPath" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    Write-Host "`n🔍 Scanning: $MinecraftPath" -ForegroundColor Green

    $ModsPath = "$MinecraftPath\mods"
    
    if (-not (Test-Path $ModsPath)) {
        Write-Host "❌ No 'mods' folder found!" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    Write-Host "`n🕵️ Advanced content analysis..." -ForegroundColor Green
    Write-Host "   Analyzing JAR files for cheat signatures..." -ForegroundColor Yellow
    
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

    foreach ($Mod in $ModFiles) {
        $TotalMods++
        $ModName = $Mod.Name
        $ModPath = $Mod.FullName
        
        Write-Host "  Analyzing: $ModName" -ForegroundColor Gray
        
        # ADVANCED CONTENT ANALYSIS
        $AnalysisResult = Analyze-ModContent -JarPath $ModPath -ModName $ModName
        
        if ($AnalysisResult.IsSuspicious) {
            $CheatModsFound++
            $ModInfo = @{
                Name = $ModName
                FilePath = $ModPath
                FileSize = "$([math]::Round($Mod.Length/1KB, 2)) KB"
                CheatTypes = $AnalysisResult.DetectionDetails -join "; "
                FileSizeMB = [math]::Round($Mod.Length/1MB, 2)
                LastModified = $Mod.LastWriteTime
                Confidence = $AnalysisResult.Confidence
                Signatures = $AnalysisResult.Signatures
            }
            $CheatModsList += $ModInfo
            
            Write-Host "    🚨 SUSPICIOUS: $($AnalysisResult.DetectionDetails -join ', ')" -ForegroundColor Red
            Write-Host "    🔍 Confidence: $($AnalysisResult.Confidence)%" -ForegroundColor Yellow
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
            Write-Host "   🔍 Confidence: $($CheatMod.Confidence)%" -ForegroundColor Cyan
            if ($CheatMod.Signatures.Count -gt 0) {
                Write-Host "   🎯 Signatures: $($CheatMod.Signatures -join ', ')" -ForegroundColor Magenta
            }
        }

        # Send results to webhook
        Send-WebhookResults -CheatModsList $CheatModsList -ComputerName $ComputerName -UserName $UserName -TotalMods $TotalMods -WebhookUrl $WebhookUrl
        
    } else {
        Write-Host "`n✅ NO SUSPICIOUS MODS DETECTED!" -ForegroundColor Green
        Write-Host "System appears clean." -ForegroundColor Green
        
        # Send clean result to webhook
        Send-WebhookResults -CheatModsList @() -ComputerName $ComputerName -UserName $UserName -TotalMods $TotalMods -WebhookUrl $WebhookUrl
    }

    Write-Host "`nScan completed: $(Get-Date)" -ForegroundColor Yellow
    Write-Host "Press Enter to exit..." -ForegroundColor Gray
    Read-Host
}

function Analyze-ModContent {
    param(
        [string]$JarPath,
        [string]$ModName
    )
    
    $Result = @{
        IsSuspicious = $false
        DetectionDetails = @()
        Confidence = 0
        Signatures = @()
    }
    
    $TempDir = $null
    
    try {
        # Create temporary directory
        $TempDir = Join-Path $env:TEMP "jar_scan_$(Get-Random)"
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
        
        # Extract JAR
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($JarPath, $TempDir)
        
        # ANALYSIS 1: Check for specific cheat signatures
        $CheatSignatures = Scan-ForCheatSignatures -ExtractPath $TempDir
        
        # ANALYSIS 2: Check for known cheat package structures
        $PackagePatterns = Scan-ForPackagePatterns -ExtractPath $TempDir
        
        # ANALYSIS 3: Check class files for suspicious methods
        $ClassAnalysis = Scan-ClassFiles -ExtractPath $TempDir
        
        # ANALYSIS 4: Check mod metadata
        $MetadataAnalysis = Scan-ModMetadata -ExtractPath $TempDir -ModName $ModName
        
        # Combine results
        $AllSignatures = @()
        $AllSignatures += $CheatSignatures.Signatures
        $AllSignatures += $PackagePatterns.Signatures
        $AllSignatures += $ClassAnalysis.Signatures
        $AllSignatures += $MetadataAnalysis.Signatures
        
        $Result.Signatures = $AllSignatures | Select-Object -Unique
        
        # Calculate confidence score
        $confidenceScore = 0
        $confidenceScore += $CheatSignatures.Confidence
        $confidenceScore += $PackagePatterns.Confidence
        $confidenceScore += $ClassAnalysis.Confidence
        $confidenceScore += $MetadataAnalysis.Confidence
        
        $Result.Confidence = [math]::Min(100, $confidenceScore)
        
        # Decide if suspicious
        if ($Result.Confidence -ge 60 -or $Result.Signatures.Count -ge 2) {
            $Result.IsSuspicious = $true
            $Result.DetectionDetails = @(
                if ($CheatSignatures.Signatures.Count -gt 0) { "Cheat signatures: $($CheatSignatures.Signatures -join ', ')" }
                if ($PackagePatterns.Signatures.Count -gt 0) { "Suspicious packages: $($PackagePatterns.Signatures -join ', ')" }
                if ($ClassAnalysis.Signatures.Count -gt 0) { "Suspicious methods: $($ClassAnalysis.Signatures -join ', ')" }
                if ($MetadataAnalysis.Signatures.Count -gt 0) { "Suspicious metadata: $($MetadataAnalysis.Signatures -join ', ')" }
            ) | Where-Object { $_ }
        }
        
    } catch {
        # Error in analysis - might be suspicious
        Write-Host "    ⚠️  Analysis error: $($_.Exception.Message)" -ForegroundColor Yellow
    } finally {
        # Cleanup
        if ($TempDir -and (Test-Path $TempDir)) {
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    return $Result
}

function Scan-ForCheatSignatures {
    param([string]$ExtractPath)
    
    $Result = @{ Signatures = @(); Confidence = 0 }
    
    # SPECIFIC CHEAT SIGNATURES (not generic terms)
    $CheatSpecificSignatures = @(
        # Meteor Client Signatures
        @{ Pattern = "meteorclient"; FileTypes = @(".class", ".java"); Confidence = 90 }
        @{ Pattern = "minegame159"; FileTypes = @(".class", ".java"); Confidence = 85 }
        @{ Pattern = "meteor\\|meteor/"; FileTypes = @(".class"); Confidence = 80 }
        
        # Wurst Client Signatures
        @{ Pattern = "net\\.wurst"; FileTypes = @(".class"); Confidence = 95 }
        @{ Pattern = "wurstclient"; FileTypes = @(".class", ".java"); Confidence = 90 }
        
        # Aristois Signatures
        @{ Pattern = "aristois"; FileTypes = @(".class", ".java"); Confidence = 85 }
        
        # Other known cheat clients
        @{ Pattern = "rusherhack"; FileTypes = @(".class", ".java"); Confidence = 85 }
        @{ Pattern = "futureclient"; FileTypes = @(".class", ".java"); Confidence = 85 }
        @{ Pattern = "lambda"; FileTypes = @(".class", ".java"); Confidence = 80 }
        
        # Baritone (often used for cheating)
        @{ Pattern = "baritone"; FileTypes = @(".class", ".java"); Confidence = 70 }
        
        # Specific cheat functions (not generic)
        @{ Pattern = "killaura|killAura"; FileTypes = @(".class"); Confidence = 75 }
        @{ Pattern = "reachhack|reachHack"; FileTypes = @(".class"); Confidence = 70 }
        @{ Pattern = "velocitymod|velocityMod"; FileTypes = @(".class"); Confidence = 70 }
        @{ Pattern = "noclip|noClip"; FileTypes = @(".class"); Confidence = 80 }
        @{ Pattern = "xrayvision|xrayVision"; FileTypes = @(".class"); Confidence = 75 }
        
        # Anti-Cheat Bypass
        @{ Pattern = "bypass|Bypass"; FileTypes = @(".class"); Confidence = 65 }
        @{ Pattern = "anticheat|antiCheat"; FileTypes = @(".class"); Confidence = 60 }
    )
    
    $AllFiles = Get-ChildItem $ExtractPath -Recurse -File -ErrorAction SilentlyContinue
    
    foreach ($File in $AllFiles) {
        foreach ($Signature in $CheatSpecificSignatures) {
            if ($File.Extension -in $Signature.FileTypes) {
                try {
                    $Content = Get-Content $File.FullName -Raw -ErrorAction Stop
                    if ($Content -and $Content -match $Signature.Pattern) {
                        $Result.Signatures += $Signature.Pattern
                        $Result.Confidence += $Signature.Confidence
                    }
                } catch {
                    # File cannot be read
                }
            }
        }
    }
    
    return $Result
}

function Scan-ForPackagePatterns {
    param([string]$ExtractPath)
    
    $Result = @{ Signatures = @(); Confidence = 0 }
    
    # Known cheat package structures
    $CheatPackages = @(
        "meteorclient", "minegame159", "net.wurst", "com.arisois",
        "rusherhack", "futureclient", "baritone.api",
        "ccbluex", "liquidbounce", "riseclient", "novoline"
    )
    
    $ClassFiles = Get-ChildItem $ExtractPath -Recurse -Filter "*.class" -ErrorAction SilentlyContinue
    
    foreach ($ClassFile in $ClassFiles) {
        $FilePath = $ClassFile.FullName.Replace($ExtractPath, "").Replace("\", "/")
        foreach ($Package in $CheatPackages) {
            if ($FilePath -match $Package) {
                $Result.Signatures += "Package: $Package"
                $Result.Confidence += 80
                break
            }
        }
    }
    
    return $Result
}

function Scan-ClassFiles {
    param([string]$ExtractPath)
    
    $Result = @{ Signatures = @(); Confidence = 0 }
    
    # Suspicious method names in Class files (as Hex/Bytecode patterns)
    $SuspiciousMethods = @(
        "killaura", "reach", "velocity", "flyhack", "nofall",
        "speedmine", "autoclick", "antiknockback", "esp",
        "tracers", "nametags", "xray", "scaffold", "nuker"
    )
    
    $ClassFiles = Get-ChildItem $ExtractPath -Recurse -Filter "*.class" -ErrorAction SilentlyContinue
    
    foreach ($ClassFile in $ClassFiles) {
        try {
            $Bytes = [System.IO.File]::ReadAllBytes($ClassFile.FullName)
            $ContentAsText = [System.Text.Encoding]::ASCII.GetString($Bytes)
            
            foreach ($Method in $SuspiciousMethods) {
                if ($ContentAsText -match $Method) {
                    $Result.Signatures += "Method: $Method"
                    $Result.Confidence += 40
                }
            }
        } catch {
            # Cannot read file
        }
    }
    
    return $Result
}

function Scan-ModMetadata {
    param([string]$ExtractPath, [string]$ModName)
    
    $Result = @{ Signatures = @(); Confidence = 0 }
    
    # Check fabric.mod.json
    $FabricModJson = Get-ChildItem $ExtractPath -Filter "fabric.mod.json" -Recurse -ErrorAction SilentlyContinue
    if ($FabricModJson) {
        try {
            $JsonContent = Get-Content $FabricModJson.FullName -Raw | ConvertFrom-Json
            $ModId = $JsonContent.id
            $Authors = $JsonContent.authors
            
            # Check for known cheat client IDs
            $KnownCheatIds = @("meteor-client", "wurst", "aristois", "lambda", "baritone")
            if ($KnownCheatIds -contains $ModId) {
                $Result.Signatures += "Cheat ID: $ModId"
                $Result.Confidence += 90
            }
        } catch {
            # Invalid JSON
        }
    }
    
    return $Result
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
            # Create embed for found cheats
            $description = "**Advanced Scan Results for $UserName@$ComputerName**`n"
            $description += "**Time:** $timestamp`n"
            $description += "**Total Mods Scanned:** $TotalMods`n"
            $description += "**Suspicious Mods Found:** $($CheatModsList.Count)`n`n"
            
            foreach ($mod in $CheatModsList) {
                $description += "🔴 **$($mod.Name)**`n"
                $description += "   Detection: $($mod.CheatTypes)`n"
                $description += "   Size: $($mod.FileSize)`n"
                $description += "   Confidence: $($mod.Confidence)%`n`n"
            }
            
            $color = 16711680  # Red
            $title = "🚨 SUSPICIOUS MODS DETECTED"
        } else {
            # Create embed for clean scan
            $description = "**Advanced Scan Results for $UserName@$ComputerName**`n"
            $description += "**Time:** $timestamp`n"
            $description += "**Total Mods Scanned:** $TotalMods`n"
            $description += "**Suspicious Mods Found:** 0`n`n"
            $description += "✅ **System appears clean**"
            
            $color = 65280  # Green
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

        # Send webhook
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload -Headers $headers
        Write-Host "✅ Results sent to webhook" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Error sending webhook: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Start scan
Start-CheatScan
