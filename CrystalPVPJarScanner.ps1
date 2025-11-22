# Minecraft Cheat Scanner - Sends Mod Files to Discord Webhook

# Discord Webhook URL - INSERT YOUR WEBHOOK HERE
$DiscordWebhookURL = "https://discord.com/api/webhooks/1441582717627142287/RAVzJaZiHjUDTG4CT96WZdr7NQD84U2e3mS8AHH4yEQ3EqicJKLxiu1o58_eyBWsWI6S"

function Start-CheatScan {
    Write-Host "=== Minecraft Cheat Scanner ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    # Simple path input
    Write-Host "`nPlease enter your Minecraft folder path:" -ForegroundColor White
    Write-Host "Examples:" -ForegroundColor Gray
    Write-Host "  - Default: C:\Users\YourName\AppData\Roaming\.minecraft" -ForegroundColor Gray
    Write-Host "  - Modrinth: C:\Users\YourName\AppData\Roaming\ModrinthApp\profiles\YourProfile" -ForegroundColor Gray

    $MinecraftPath = Read-Host "`nEnter path"

    # Check if path exists
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

    # Cheat code patterns
    $CheatCodePatterns = @(
        "killaura", "reach", "velocity", "autoclick", "aimassist",
        "triggerbot", "antibot", "speedmine", "nuker", "scaffold",
        "nofall", "flight", "xray", "esp", "crystalaura", "autopot",
        "elytra.*boost", "anchor.*optimizer", "interactive.*speed"
    )

    # Scan mods folder
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
    $ScanTime = Get-Date
    $ComputerName = $env:COMPUTERNAME
    $UserName = $env:USERNAME

    # Search all JAR files in mods folder
    $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction SilentlyContinue

    foreach ($Mod in $ModFiles) {
        $TotalMods++
        $ModName = $Mod.Name
        $ModNameLower = $Mod.Name.ToLower()
        
        Write-Host "  Scanning: $ModName" -ForegroundColor Gray
        
        # Check if it's a known cheat mod
        $IsKnownCheat = $false
        $DetectedCheatType = ""
        foreach ($CheatMod in $KnownCheatMods) {
            if ($ModNameLower -match $CheatMod) {
                $IsKnownCheat = $true
                $DetectedCheatType = $CheatMod
                break
            }
        }

        $CheatAnalysis = @{
            ContainsCheats = $false
            CheatEvidence = @()
            CheatType = ""
            FilePath = $Mod.FullName
            FileSize = "$([math]::Round($Mod.Length/1KB, 2)) KB"
        }

        if ($IsKnownCheat) {
            $CheatAnalysis.ContainsCheats = $true
            $CheatAnalysis.CheatType = $DetectedCheatType
            $CheatAnalysis.CheatEvidence += "Known cheat mod: $DetectedCheatType"
        } else {
            # Deep scan for cheat code
            $DeepAnalysis = Find-CheatCodeInJar -FilePath $Mod.FullName -ModName $ModName
            if ($DeepAnalysis.ContainsCheats) {
                $CheatAnalysis.ContainsCheats = $true
                $CheatAnalysis.CheatEvidence = $DeepAnalysis.CheatEvidence
                $CheatAnalysis.CheatType = "Custom Cheat"
            }
        }
        
        if ($CheatAnalysis.ContainsCheats) {
            $CheatModsFound++
            $CheatModsList += @{
                Name = $ModName
                FilePath = $Mod.FullName
                FileSize = $CheatAnalysis.FileSize
                CheatEvidence = $CheatAnalysis.CheatEvidence
                CheatType = $CheatAnalysis.CheatType
            }
            
            Write-Host "    🚨 CHEAT DETECTED: $($CheatAnalysis.CheatType)" -ForegroundColor Red
            
            # Send this cheat mod to Discord immediately
            Send-CheatToDiscord -ModInfo $CheatModsList[-1] -ComputerName $ComputerName -UserName $UserName
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
        Write-Host "-" * 50 -ForegroundColor Red
        
        foreach ($CheatMod in $CheatModsList) {
            Write-Host "`n❌ $($CheatMod.Name) ($($CheatMod.FileSize))" -ForegroundColor Red
            Write-Host "   Type: $($CheatMod.CheatType)" -ForegroundColor Yellow
            foreach ($evidence in $CheatMod.CheatEvidence) {
                Write-Host "   ⚠ $evidence" -ForegroundColor Yellow
            }
        }

        # Send final summary to Discord
        Send-SummaryToDiscord -CheatModsList $CheatModsList -TotalMods $TotalMods -ComputerName $ComputerName -UserName $UserName

        Write-Host "`n" + "!"*50 -ForegroundColor Red
        Write-Host "CHEAT MODS SENT TO DISCORD!" -ForegroundColor Red
        Write-Host "!"*50 -ForegroundColor Red
    } else {
        Write-Host "`n✅ NO CHEAT MODS DETECTED!" -ForegroundColor Green
        Write-Host "Your mod folder is clean." -ForegroundColor Green
        
        # Send clean report to Discord
        Send-CleanReportToDiscord -TotalMods $TotalMods -ComputerName $ComputerName -UserName $UserName
    }

    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to send individual cheat mod to Discord with file attachment
function Send-CheatToDiscord {
    param(
        [hashtable]$ModInfo,
        [string]$ComputerName,
        [string]$UserName
    )
    
    try {
        # Create multipart form data
        $Boundary = [System.Guid]::NewGuid().ToString()
        $ContentType = "multipart/form-data; boundary=$Boundary"
        
        # Create the body
        $Body = @"
--$Boundary
Content-Disposition: form-data; name="payload_json"
Content-Type: application/json

{
    "embeds": [
        {
            "title": "🚨 CHEAT MOD DETECTED",
            "color": 16711680,
            "fields": [
                {
                    "name": "Mod File",
                    "value": "```$($ModInfo.Name)```",
                    "inline": true
                },
                {
                    "name": "Cheat Type",
                    "value": "```$($ModInfo.CheatType)```",
                    "inline": true
                },
                {
                    "name": "File Size",
                    "value": "```$($ModInfo.FileSize)```",
                    "inline": true
                },
                {
                    "name": "Computer",
                    "value": "```$ComputerName```",
                    "inline": true
                },
                {
                    "name": "User",
                    "value": "```$UserName```",
                    "inline": true
                },
                {
                    "name": "Evidence",
                    "value": "$(($ModInfo.CheatEvidence -join '\n') -replace '"', '\"')"
                }
            ],
            "timestamp": "$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")",
            "footer": {
                "text": "Minecraft Cheat Scanner"
            }
        }
    ]
}
--$Boundary
Content-Disposition: form-data; name="file"; filename="$($ModInfo.Name)"
Content-Type: application/java-archive

"@

        # Read the file bytes
        $FileBytes = [System.IO.File]::ReadAllBytes($ModInfo.FilePath)
        $Encoding = [System.Text.Encoding]::GetEncoding("iso-8859-1")
        
        # Convert body to bytes
        $BodyBytes = $Encoding.GetBytes($Body)
        
        # Combine body + file + footer
        $FinalBytes = $BodyBytes + $FileBytes + $Encoding.GetBytes("`r`n--$Boundary--`r`n")
        
        # Send to Discord
        $Response = Invoke-RestMethod -Uri $DiscordWebhookURL -Method Post -ContentType $ContentType -Body $FinalBytes
        
        Write-Host "    📤 Sent to Discord: $($ModInfo.Name)" -ForegroundColor Green
        
    } catch {
        Write-Host "    ❌ Failed to send to Discord: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to send final summary to Discord
function Send-SummaryToDiscord {
    param(
        [array]$CheatModsList,
        [int]$TotalMods,
        [string]$ComputerName,
        [string]$UserName
    )
    
    try {
        $CheatModsText = $CheatModsList | ForEach-Object { 
            "• $($_.Name) - $($_.CheatType) ($($_.FileSize))"
        }
        
        $SummaryJSON = @{
            embeds = @(
                @{
                    title = "📊 SCAN SUMMARY - CHEATS FOUND"
                    color = 16711680
                    fields = @(
                        @{
                            name = "Computer"
                            value = "```$ComputerName```"
                            inline = $true
                        },
                        @{
                            name = "User"
                            value = "```$UserName```"
                            inline = $true
                        },
                        @{
                            name = "Scan Time"
                            value = "```$(Get-Date)```"
                            inline = $true
                        },
                        @{
                            name = "Files Scanned"
                            value = "```$TotalMods```"
                            inline = $true
                        },
                        @{
                            name = "Cheats Found"
                            value = "```$($CheatModsList.Count)```"
                            inline = $true
                        },
                        @{
                            name = "Detected Cheats"
                            value = ($CheatModsText -join "`n")
                        }
                    )
                    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                    footer = @{
                        text = "Minecraft Cheat Scanner - $($CheatModsList.Count) files uploaded"
                    }
                }
            )
        } | ConvertTo-Json -Depth 10
        
        Invoke-RestMethod -Uri $DiscordWebhookURL -Method Post -Body $SummaryJSON -ContentType "application/json"
        
    } catch {
        Write-Host "    ❌ Failed to send summary to Discord" -ForegroundColor Red
    }
}

# Function to send clean report
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
                        @{
                            name = "Computer"
                            value = "```$ComputerName```"
                            inline = $true
                        },
                        @{
                            name = "User"
                            value = "```$UserName```"
                            inline = $true
                        },
                        @{
                            name = "Files Scanned"
                            value = "```$TotalMods```"
                            inline = $true
                        },
                        @{
                            name = "Cheats Found"
                            value = "```0```"
                            inline = $true
                        },
                        @{
                            name = "Status"
                            value = "✅ All mods are clean"
                        }
                    )
                    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                    footer = @{
                        text = "Minecraft Cheat Scanner"
                    }
                }
            )
        } | ConvertTo-Json -Depth 10
        
        Invoke-RestMethod -Uri $DiscordWebhookURL -Method Post -Body $CleanJSON -ContentType "application/json"
        
    } catch {
        Write-Host "    ❌ Failed to send clean report to Discord" -ForegroundColor Red
    }
}

# Function to find cheat code in JAR files
function Find-CheatCodeInJar {
    param(
        [string]$FilePath,
        [string]$ModName
    )
    
    $Result = @{
        ContainsCheats = $false
        CheatEvidence = @()
    }
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
        
        foreach ($Entry in $ZipFile.Entries) {
            $EntryName = $Entry.Name
            $EntryNameLower = $Entry.Name.ToLower()
            
            # Check file names for cheat patterns
            foreach ($Pattern in $CheatCodePatterns) {
                if ($EntryNameLower -match $Pattern) {
                    $Result.ContainsCheats = $true
                    $Result.CheatEvidence += "Contains cheat file: $Pattern ($EntryName)"
                    break
                }
            }
        }
        
        $ZipFile.Dispose()
        
    } catch {
        $Result.ContainsCheats = $true
        $Result.CheatEvidence += "Could not scan JAR - possibly obfuscated cheat"
    }
    
    return $Result
}

# Start the scan
Start-CheatScan
