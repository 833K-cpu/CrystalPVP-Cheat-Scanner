# Minecraft Cheat Scanner - Sends ALL MODs as attachments in ONE message

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

        # Send ALL mods in ONE message with attachments
        Send-AllModsToDiscord -CheatModsList $CheatModsList -TotalMods $TotalMods -ComputerName $ComputerName -UserName $UserName

        Write-Host "`n📤 ALL $CheatModsFound MODS SENT TO DISCORD IN ONE MESSAGE!" -ForegroundColor Green
        Write-Host "   All files are attached and downloadable" -ForegroundColor Green
    } else {
        Write-Host "`n✅ NO CHEAT MODS DETECTED!" -ForegroundColor Green
        Send-CleanReportToDiscord -TotalMods $TotalMods -ComputerName $ComputerName -UserName $UserName
    }

    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Send-AllModsToDiscord {
    param(
        [array]$CheatModsList,
        [int]$TotalMods,
        [string]$ComputerName,
        [string]$UserName
    )
    
    try {
        $Boundary = [System.Guid]::NewGuid().ToString()
        $ContentType = "multipart/form-data; boundary=$Boundary"
        
        # Create file list for description
        $FileList = $CheatModsList | ForEach-Object { 
            "• $($_.Name) - $($_.CheatType) ($($_.FileSize))"
        }
        
        # Create JSON payload
        $JsonPayload = @{
            embeds = @(
                @{
                    title = "🚨 ALL CHEAT MODS - DOWNLOAD ATTACHMENTS"
                    color = 16711680
                    fields = @(
                        @{ name = "💻 Computer"; value = $ComputerName; inline = $true },
                        @{ name = "👤 User"; value = $UserName; inline = $true },
                        @{ name = "📁 Total Files Scanned"; value = $TotalMods; inline = $true },
                        @{ name = "🚨 Cheat Mods Found"; value = $CheatModsList.Count; inline = $true },
                        @{ name = "🕒 Scan Time"; value = (Get-Date -Format "HH:mm:ss"); inline = $true }
                    )
                    description = "**All detected cheat mods are attached below ↓**`n`n**File List:**`n" + ($FileList -join "`n")
                    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                    footer = @{ text = "Minecraft Cheat Scanner - Click attachments to download" }
                }
            )
        } | ConvertTo-Json -Depth 10

        # Start building multipart form
        $Body = @"
--$Boundary
Content-Disposition: form-data; name="payload_json"
Content-Type: application/json

$JsonPayload
"@

        # Add each mod file as attachment
        foreach ($Mod in $CheatModsList) {
            if ($Mod.FileSizeMB -le 25) { # Skip files larger than 25MB
                $FileBytes = [System.IO.File]::ReadAllBytes($Mod.FilePath)
                $Body += @"

--$Boundary
Content-Disposition: form-data; name="files[$($CheatModsList.IndexOf($Mod))]"; filename="$($Mod.Name)"
Content-Type: application/java-archive

"@
                $BodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
                $BodyBytes += $FileBytes
                $Body = [System.Text.Encoding]::UTF8.GetString($BodyBytes)
            } else {
                Write-Host "    ⚠ Skipped large file: $($Mod.Name) ($($Mod.FileSizeMB)MB)" -ForegroundColor Yellow
            }
        }

        # Close the boundary
        $Body += "`r`n--$Boundary--`r`n"

        # Send to Discord
        $Encoding = [System.Text.Encoding]::GetEncoding("iso-8859-1")
        $BodyBytes = $Encoding.GetBytes($Body)
        
        $Response = Invoke-RestMethod -Uri $DiscordWebhookURL -Method Post -ContentType $ContentType -Body $BodyBytes
        
        Write-Host "    📤 Sent $($CheatModsList.Count) mods to Discord in one message" -ForegroundColor Green
        
    } catch {
        Write-Host "    ❌ Failed to send mods to Discord: $($_.Exception.Message)" -ForegroundColor Red
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
