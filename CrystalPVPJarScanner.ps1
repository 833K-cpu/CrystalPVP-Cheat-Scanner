# Minecraft Cheat Scanner - Screenshare Tool
function Start-CheatScan {
    Write-Host "=== MINECRAFT SCREENSHARE SCANNER ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    # Auto-detect paths
    $DefaultPath = "$env:APPDATA\.minecraft"
    $ModrinthPath = "$env:APPDATA\ModrinthApp\profiles"
    
    Write-Host "`nAuto-detecting Minecraft folders..." -ForegroundColor Green
    
    $DetectedPaths = @()
    if (Test-Path $DefaultPath) { $DetectedPaths += $DefaultPath }
    
    # Find Modrinth profiles
    if (Test-Path $ModrinthPath) {
        $ModrinthProfiles = Get-ChildItem $ModrinthPath -Directory -ErrorAction SilentlyContinue
        foreach ($profile in $ModrinthProfiles) {
            $DetectedPaths += $profile.FullName
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

    # Enhanced cheat detection
    $KnownCheatMods = @(
        "osmium", "elytraboost", "cwe", "crystaloptimizer",
        "heroanchor", "anchoroptimizer", "ias", "interactivespeed", 
        "cookeymod", "reflex", "vulcan", "verus", "cwb",
        "future", "wurst", "aristois", "meteor", "bleach",
        "inertia", "lambda", "rusherhack", "pyro", "kami",
        "konas", "phobos", "w+", "wolfram", "gamesense"
    )

    $ModsPath = "$MinecraftPath\mods"
    
    if (-not (Test-Path $ModsPath)) {
        Write-Host "❌ No 'mods' folder found!" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    Write-Host "`n🕵️ Scanning for cheat mods..." -ForegroundColor Green
    
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
        $ModNameLower = $Mod.Name.ToLower()
        
        Write-Host "  Scanning: $ModName" -ForegroundColor Gray
        
        $DetectedCheats = @()
        foreach ($CheatMod in $KnownCheatMods) {
            if ($ModNameLower -match $CheatMod) {
                $DetectedCheats += $CheatMod
            }
        }

        if ($DetectedCheats.Count -gt 0) {
            $CheatModsFound++
            $ModInfo = @{
                Name = $ModName
                FilePath = $Mod.FullName
                FileSize = "$([math]::Round($Mod.Length/1KB, 2)) KB"
                CheatTypes = $DetectedCheats -join ", "
                FileSizeMB = [math]::Round($Mod.Length/1MB, 2)
                LastModified = $Mod.LastWriteTime
            }
            $CheatModsList += $ModInfo
            
            Write-Host "    🚨 CHEAT DETECTED: $($DetectedCheats -join ', ')" -ForegroundColor Red
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
        Write-Host "🚨 CHEAT MODS FOUND: $CheatModsFound" -ForegroundColor Red
        
        foreach ($CheatMod in $CheatModsList) {
            Write-Host "`n❌ $($CheatMod.Name)" -ForegroundColor Red
            Write-Host "   📁 Type: $($CheatMod.CheatTypes)" -ForegroundColor Yellow
            Write-Host "   📦 Size: $($CheatMod.FileSize)" -ForegroundColor Gray
            Write-Host "   🕒 Modified: $($CheatMod.LastModified)" -ForegroundColor Gray
        }

        # Send to Discord
        Write-Host "`n📤 Sending results to Discord..." -ForegroundColor Green
        Send-ToDiscordBot -CheatModsList $CheatModsList -TotalMods $TotalMods -ComputerName $ComputerName -UserName $UserName -MinecraftPath $MinecraftPath
        
    } else {
        Write-Host "`n✅ NO CHEAT MODS DETECTED!" -ForegroundColor Green
        Write-Host "System appears clean." -ForegroundColor Green
    }

    Write-Host "`nScan completed: $(Get-Date)" -ForegroundColor Yellow
    if ($CheatModsFound -gt 0) {
        Write-Host "💡 Use '/download_mod [mod_name]' in Discord to download suspicious files" -ForegroundColor Cyan
    }
    Read-Host "Press Enter to exit"
}

function Send-ToDiscordBot {
    param(
        [array]$CheatModsList,
        [int]$TotalMods,
        [string]$ComputerName,
        [string]$UserName,
        [string]$MinecraftPath
    )
    
    try {
        $FileList = $CheatModsList | ForEach-Object { 
            "📎 `"$($_.Name)`" - **$($_.CheatTypes)** ($($_.FileSize))"
        }
        
        $LatestMod = $CheatModsList[0].Name
        
        $MessageContent = "**🚨 SCREENSHARE SCAN COMPLETED - $($CheatModsList.Count) CHEAT MODS FOUND**`n`n"
        $MessageContent += "**📊 Scan Information:**`n"
        $MessageContent += "💻 **Computer:** $ComputerName`n"
        $MessageContent += "👤 **User:** $UserName`n"  
        $MessageContent += "📁 **Total Files Scanned:** $TotalMods`n"
        $MessageContent += "🚨 **Cheat Mods Found:** $($CheatModsList.Count)`n"
        $MessageContent += "🕒 **Scan Time:** $(Get-Date -Format 'HH:mm:ss')`n`n"
        $MessageContent += "**📁 Detected Cheat Mods:**`n"
        $MessageContent += "$($FileList -join "`n")`n`n"
        $MessageContent += "**📍 Scan Path:** $MinecraftPath`n`n"
        $MessageContent += "**📥 Download Commands:**`n"
        foreach ($mod in $CheatModsList) {
            $MessageContent += "• `/download_mod $($mod.Name)`\n"
        }
        $MessageContent += "`n**⚡ Latest suspicious mod:** `$LatestMod`"

        $Body = @{
            content = $MessageContent
            username = "Screenshare Scanner"
            avatar_url = "https://cdn.discordapp.com/emojis/1065110917820117022.webp"
        } | ConvertTo-Json -Depth 10

        $WebhookURL = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S"
        
        Invoke-RestMethod -Uri $WebhookURL -Method Post -Body $Body -ContentType "application/json" -ErrorAction Stop
        
        Write-Host "    ✅ Results sent to Discord!" -ForegroundColor Green
        
    } catch {
        Write-Host "    ❌ Failed to send to Discord: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Start scan
Start-CheatScan
