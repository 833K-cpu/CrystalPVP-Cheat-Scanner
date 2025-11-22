# Minecraft Cheat Scanner - Sends MODs as replies to summary

# Discord Webhook URL - INSERT YOUR WEBHOOK HERE
$DiscordWebhookURL = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S"

function Start-CheatScan {
    Write-Host "=== Minecraft Cheat Scanner ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    Write-Host "`nPlease enter your Minecraft folder path:" -ForegroundColor White
    Write-Host "Examples:" -ForegroundColor Gray
    Write-Host "  - Default: C:\Users\YourName\AppData\Roaming\.minecraft" -ForegroundColor Gray
    Write-Host "  - Modrinth: C:\Users\YourName\AppData\Roaming\ModrinthApp\profiles\YourProfile" -ForegroundColor Gray

    $MinecraftPath = Read-Host "`nEnter path"

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

    $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction SilentlyContinue

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

        # First send the summary message and get its ID
        $SummaryMessageId = Send-SummaryToDiscord -CheatModsList $CheatModsList -TotalMods $TotalMods -ComputerName $ComputerName -UserName $UserName

        # Then send each mod as a reply to the summary
        if ($SummaryMessageId) {
            foreach ($Mod in $CheatModsList) {
                Send-ModAsReply -ModInfo $Mod -ReplyToMessageId $SummaryMessageId
                Start-Sleep -Milliseconds 500  # Small delay to avoid rate limits
            }
        }

        Write-Host "`n📤 $CheatModsFound MODS SENT AS REPLIES TO SUMMARY!" -ForegroundColor Green
    } else {
        Write-Host "`n✅ NO CHEAT MODS DETECTED!" -ForegroundColor Green
        Send-CleanReportToDiscord -TotalMods $TotalMods -ComputerName $ComputerName -UserName $UserName
    }

    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Send-SummaryToDiscord {
    param(
        [array]$CheatModsList,
        [int]$TotalMods,
        [string]$ComputerName,
        [string]$UserName
    )
    
    try {
        $FileList = $CheatModsList | ForEach-Object { 
            "• $($_.Name) - $($_.CheatType) ($($_.FileSize))"
        }
        
        $SummaryJSON = @{
            embeds = @(
                @{
                    title = "📊 SCAN SUMMARY - $($CheatModsList.Count) CHEAT MODS FOUND"
                    color = 16711680
                    fields = @(
                        @{ name = "💻 Computer"; value = $ComputerName; inline = $true },
                        @{ name = "👤 User"; value = $UserName; inline = $true },
                        @{ name = "📁 Files Scanned"; value = $TotalMods; inline = $true },
                        @{ name = "🚨 Cheats Found"; value = $($CheatModsList.Count); inline = $true },
                        @{ name = "🕒 Scan Time"; value = (Get-Date -Format "HH:mm:ss"); inline = $true }
                    )
                    description = "**Detected cheat mods will be attached as replies below ↓**`n`n**File List:**`n" + ($FileList -join "`n")
                    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                    footer = @{ text = "Minecraft Cheat Scanner - Check replies for file attachments" }
                }
            )
        } | ConvertTo-Json -Depth 10
        
        $Response = Invoke-RestMethod -Uri $DiscordWebhookURL -Method Post -Body $SummaryJSON -ContentType "application/json"
        
        # Extract message ID from response (if available)
        if ($Response -and $Response.id) {
            Write-Host "    📤 Summary message sent (ID: $($Response.id))" -ForegroundColor Green
            return $Response.id
        } else {
            Write-Host "    📤 Summary message sent" -ForegroundColor Green
            return $null
        }
        
    } catch {
        Write-Host "    ❌ Failed to send summary to Discord: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Send-ModAsReply {
    param(
        [hashtable]$ModInfo,
        [string]$ReplyToMessageId
    )
    
    try {
        # Check file size (Discord limit: 25MB)
        if ($ModInfo.FileSizeMB -gt 25) {
            Write-Host "    ⚠ File too large for Discord: $($ModInfo.Name) ($($ModInfo.FileSizeMB)MB)" -ForegroundColor Yellow
            return
        }

        $Boundary = [System.Guid]::NewGuid().ToString()
        $ContentType = "multipart/form-data; boundary=$Boundary"
        
        # Create JSON payload with message_reference for reply
        $JsonPayload = @{
            embeds = @(
                @{
                    title = "📎 MOD ATTACHMENT"
                    color = 3447003
                    fields = @(
                        @{ name = "📁 File"; value = $ModInfo.Name; inline = $true },
                        @{ name = "🔍 Type"; value = $ModInfo.CheatType; inline = $true },
                        @{ name = "📊 Size"; value = $ModInfo.FileSize; inline = $true }
                    )
                    description = "**Click to download this cheat mod**"
                    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                }
            )
        }

        # Add message_reference if we have a message ID to reply to
        if ($ReplyToMessageId) {
            $JsonPayload["message_reference"] = @{
                message_id = $ReplyToMessageId
            }
        }

        $JsonPayload = $JsonPayload | ConvertTo-Json -Depth 10

        # Build multipart form with file
        $Body = @"
--$Boundary
Content-Disposition: form-data; name="payload_json"
Content-Type: application/json

$JsonPayload
--$Boundary
Content-Disposition: form-data; name="file"; filename="$($ModInfo.Name)"
Content-Type: application/java-archive

"@

        # Read and send file
        $FileBytes = [System.IO.File]::ReadAllBytes($ModInfo.FilePath)
        $Encoding = [System.Text.Encoding]::GetEncoding("iso-8859-1")
        $BodyBytes = $Encoding.GetBytes($Body)
        $FinalBytes = $BodyBytes + $FileBytes + $Encoding.GetBytes("`r`n--$Boundary--`r`n")
        
        # Send to Discord
        $Response = Invoke-RestMethod -Uri $DiscordWebhookURL -Method Post -ContentType $ContentType -Body $FinalBytes
        
        Write-Host "    📎 Sent as reply: $($ModInfo.Name)" -ForegroundColor Green
        
    } catch {
        Write-Host "    ❌ Failed to send mod as reply: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Send-CleanReportToDiscord {
    param(
        [int]$TotalMods,
        [string]$ComputerName,
        [string]$UserName
    )
    
    try {
        $CleanJSON = @{
            embeds = @(
                @{
                    title = "✅ SCAN SUMMARY - CLEAN SYSTEM"
                    color = 65280
                    fields = @(
                        @{ name = "💻 Computer"; value = $ComputerName; inline = $true },
                        @{ name = "👤 User"; value = $UserName; inline = $true },
                        @{ name = "📁 Files Scanned"; value = $TotalMods; inline = $true },
                        @{ name = "🚨 Cheats Found"; value = "0"; inline = $true },
                        @{ name = "🕒 Scan Time"; value = (Get-Date -Format "HH:mm:ss"); inline = $true }
                    )
                    description = "**No cheat mods detected - System is clean**"
                    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                    footer = @{ text = "Minecraft Cheat Scanner" }
                }
            )
        } | ConvertTo-Json -Depth 10
        
        Invoke-RestMethod -Uri $DiscordWebhookURL -Method Post -Body $CleanJSON -ContentType "application/json"
        
    } catch {
        Write-Host "    ❌ Failed to send clean report to Discord" -ForegroundColor Red
    }
}

# Start the scan
Start-CheatScan
