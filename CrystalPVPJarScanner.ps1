# Minecraft Cheat Scanner - Sends results to Discord Bot

function Start-CheatScan {
    Write-Host "=== Minecraft Cheat Scanner ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    # Try to find Minecraft path automatically
    $DefaultPath = "$env:APPDATA\.minecraft"
    $ModrinthPath = "$env:APPDATA\ModrinthApp\profiles"
    
    Write-Host "`nPlease enter your Minecraft folder path:" -ForegroundColor White
    Write-Host "Examples:" -ForegroundColor Gray
    Write-Host "  - Default: $DefaultPath" -ForegroundColor Gray
    Write-Host "  - Modrinth: $ModrinthPath\YourProfile" -ForegroundColor Gray
    Write-Host "  - Press Enter to use default path" -ForegroundColor Yellow

    $MinecraftPath = Read-Host "`nEnter path"
    
    if ([string]::IsNullOrWhiteSpace($MinecraftPath)) {
        $MinecraftPath = $DefaultPath
    }

    if (-not (Test-Path $MinecraftPath)) {
        Write-Host "ERROR: This path does not exist!" -ForegroundColor Red
        Write-Host "Please check the path and try again." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit
    }

    Write-Host "`n✅ Scanning: $MinecraftPath" -ForegroundColor Green

    # Known cheat mods
    $KnownCheatMods = @(
        "osmium", "elytraboost", "cwe", "crystaloptimizer",
        "heroanchor", "anchoroptimizer", "ias", "interactivespeed", 
        "cookeymod", "reflex", "vulcan", "verus", "cwb"
    )

    $ModsPath = "$MinecraftPath\mods"
    
    if (-not (Test-Path $ModsPath)) {
        Write-Host "❌ No 'mods' folder found!" -ForegroundColor Red
        Write-Host "Make sure you entered the correct path." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit
    }

    Write-Host "`n🔍 Scanning for cheat mods..." -ForegroundColor Green
    
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
        
        $IsKnownCheat = $false
        $DetectedCheatType = ""
        foreach ($CheatMod in $KnownCheatMods) {
            if ($ModNameLower -match $CheatMod) {
                $IsKnownCheat = $true
                $DetectedCheatType = $CheatMod
                break
            }
        }

        if ($IsKnownCheat) {
            $CheatModsFound++
            $ModInfo = @{
                Name = $ModName
                FilePath = $Mod.FullName
                FileSize = "$([math]::Round($Mod.Length/1KB, 2)) KB"
                CheatType = $DetectedCheatType
                FileSizeMB = [math]::Round($Mod.Length/1MB, 2)
            }
            $CheatModsList += $ModInfo
            
            Write-Host "    🚨 CHEAT DETECTED: $DetectedCheatType" -ForegroundColor Red
        } else {
            Write-Host "    ✅ Clean" -ForegroundColor Green
        }
    }

    # Display results
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "CHEAT DETECTION RESULTS" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan
    
    Write-Host "JAR files scanned: $TotalMods" -ForegroundColor White
    
    if ($CheatModsFound -gt 0) {
        Write-Host "🚨 CHEAT MODS FOUND: $CheatModsFound" -ForegroundColor Red
        
        foreach ($CheatMod in $CheatModsList) {
            Write-Host "`n❌ $($CheatMod.Name) ($($CheatMod.FileSize))" -ForegroundColor Red
            Write-Host "   Type: $($CheatMod.CheatType)" -ForegroundColor Yellow
        }

        # Send results to Discord Bot
        Write-Host "`n📤 Sending results to Discord Bot..." -ForegroundColor Green
        Send-ToDiscordBot -CheatModsList $CheatModsList -TotalMods $TotalMods -ComputerName $ComputerName -UserName $UserName -MinecraftPath $MinecraftPath
        
    } else {
        Write-Host "`n✅ NO CHEAT MODS DETECTED!" -ForegroundColor Green
    }

    Write-Host "`nScan completed: $(Get-Date)" -ForegroundColor Yellow
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
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
        # Create detailed results message
        $FileList = $CheatModsList | ForEach-Object { 
            "📎 `"$($_.Name)`" - **$($_.CheatType)** ($($_.FileSize))"
        }
        
        $MessageContent = @"
**🚨 LOCAL SCAN COMPLETED - $($CheatModsList.Count) CHEAT MODS FOUND**

**📊 Scan Information:**
💻 **Computer:** $ComputerName
👤 **User:** $UserName  
📁 **Total Files Scanned:** $TotalMods
🚨 **Cheat Mods Found:** $($CheatModsList.Count)
🕒 **Scan Time:** $(Get-Date -Format "HH:mm:ss")

**📁 Detected Cheat Mods:**
$($FileList -join "`n")

**📍 Scan Path:** $MinecraftPath
**⚡ Run `/scan $MinecraftPath` on the bot to download these files**
"@

        # Send to Discord via Webhook
        $Body = @{
            content = $MessageContent
            username = "Minecraft Scanner"
            avatar_url = "https://cdn.discordapp.com/emojis/1065110917820117022.webp"
        } | ConvertTo-Json -Depth 10

        $WebhookURL = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S"
        
        $Response = Invoke-RestMethod -Uri $WebhookURL -Method Post -Body $Body -ContentType "application/json" -ErrorAction Stop
        
        Write-Host "    ✅ Results sent to Discord Bot!" -ForegroundColor Green
        Write-Host "    💡 Use '/scan $MinecraftPath' on the bot to download files" -ForegroundColor Cyan
        
    } catch {
        Write-Host "    ❌ Failed to send to Discord: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Start the scan
Start-CheatScan
