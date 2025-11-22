# Minecraft Cheat Scanner - Complete Version with Discord Webhook
# Detects cheat mods and sends files to Discord

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

    # Cheat code patterns for deep scanning
    $CheatCodePatterns = @(
        "killaura", "reach", "velocity", "autoclick", "aimassist",
        "triggerbot", "antibot", "speedmine", "nuker", "scaffold",
        "nofall", "flight", "xray", "esp", "crystalaura", "autopot",
        "elytra.*boost", "anchor.*optimizer", "interactive.*speed",
        "hitboxes", "nametags", "tracers", "radar"
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
            # Deep scan for cheat code in JAR files
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
            foreach ($evidence in $CheatAnalysis.CheatEvidence) {
                Write-Host "      ⚠ $evidence" -ForegroundColor Yellow
            }
            
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
    Write-Host "✅ Clean mods: $($TotalMods - $CheatModsFound)" -ForegroundColor Green
    Write-Host "🚨 Cheat mods: $CheatModsFound" -ForegroundColor Red
    
    if ($CheatModsFound -gt 0) {
        Write-Host "`n🚨 DETECTED CHEAT MODS:" -ForegroundColor Red
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

    # Scan running processes for cheat clients
    Write-Host "`n🔍 Checking running processes..." -ForegroundColor Green
    $SuspiciousProcesses = Scan-RunningProcesses
    if ($SuspiciousProcesses.Count -gt 0) {
        Write-Host "❌ Suspicious processes found:" -ForegroundColor Red
        foreach ($proc in $SuspiciousProcesses) {
            Write-Host "  - $proc" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✅ No suspicious processes found" -ForegroundColor Green
    }

    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Find-CheatCodeInJar {
    param(
        [string]$FilePath,
        [string]$ModName
    )
    
    $Result = @{
        ContainsCheats = $false
        CheatEvidence = @()
        FilesScanned = 0
    }
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
        
        # Scan each file in the JAR
        foreach ($Entry in $ZipFile.Entries) {
            $Result.FilesScanned++
            $EntryName = $Entry.Name
            $EntryNameLower = $Entry.Name.ToLower()
            
            # Skip binary files and very small files
            if ($Entry.Length -lt 10) { continue }
            if ($EntryName -match '\.class$|\.png$|\.jpg$|\.ogg$|\.wav$') { continue }
            
            # Check file names for cheat patterns
            foreach ($Pattern in $CheatCodePatterns) {
                if ($EntryNameLower -match $Pattern) {
                    $Result.ContainsCheats = $true
                    $Result.CheatEvidence += "Contains cheat file: $Pattern ($EntryName)"
                    break
                }
            }
            
            # Analyze text files for cheat code
            if ($EntryName -match '\.(java|json|txt|yml|yaml|properties|cfg|config|mcmeta)$') {
                if ($Entry.Length -lt 50000) { # Only read files under 50KB
                    try {
                        $Stream = $Entry.Open()
                        $Reader = New-Object System.IO.StreamReader($Stream)
                        $Content = $Reader.ReadToEnd()
                        $Reader.Close()
                        $Stream.Close()
                        
                        $ContentLower = $Content.ToLower()
                        
                        # Look for actual cheat code implementations
                        if ($ContentLower -match 'killaura|entityaura|attackallentities') {
                            $Result.ContainsCheats = $true
                            $Result.CheatEvidence += "Contains KillAura implementation"
                        }
                        elseif ($ContentLower -match 'reach.*[3-9]\.|attackrange.*[3-9]') {
                            $Result.ContainsCheats = $true
                            $Result.CheatEvidence += "Contains Reach hack code"
                        }
                        elseif ($ContentLower -match 'velocity.*0\.|knockback.*0\.') {
                            $Result.ContainsCheats = $true
                            $Result.CheatEvidence += "Contains Velocity hack code"
                        }
                        elseif ($ContentLower -match 'autoclick|autoclicker|clickspam') {
                            $Result.ContainsCheats = $true
                            $Result.CheatEvidence += "Contains AutoClicker code"
                        }
                        elseif ($ContentLower -match 'aimassist|aimbot|lockontarget') {
                            $Result.ContainsCheats = $true
                            $Result.CheatEvidence += "Contains AimAssist code"
                        }
                    } catch {
                        # Skip files that can't be read
                    }
                }
            }
            
            # Limit scanning to prevent timeout
            if ($Result.FilesScanned -gt 500) {
                $Result.CheatEvidence += "Stopped after scanning 500 files"
                break
            }
        }
        
        $ZipFile.Dispose()
        
    } catch {
        $Result.CheatEvidence += "Could not scan JAR contents: $($_.Exception.Message)"
    }
    
    return $Result
}

function Scan-RunningProcesses {
    $CheatProcesses = @(
        "wurst", "sigma", "impact", "liquidbounce", "raven",
        "novoline", "tenacity", "lambda", "gamesense"
    )
    
    $Suspicious = @()
    
    try {
        $processes = Get-Process | Where-Object { 
            $procName = $_.ProcessName.ToLower()
            $CheatProcesses | Where-Object { $procName -match $_ }
        }
        
        foreach ($proc in $processes) {
            $Suspicious += $proc.ProcessName
        }
    } catch {
        # Ignore process scanning errors
    }
    
    return $Suspicious
}

function Send-CheatToDiscord {
    param(
        [hashtable]$ModInfo,
        [string]$ComputerName,
        [string]$UserName
    )
    
    try {
        # Create multipart form data for file upload
        $Boundary = [System.Guid]::NewGuid().ToString()
        $ContentType = "multipart/form-data; boundary=$Boundary"
        
        # Create JSON payload for Discord embed
        $JsonPayload = @{
            embeds = @(
                @{
                    title = "🚨 CHEAT MOD DETECTED"
                    color = 16711680
                    fields = @(
                        @{ name = "Mod File"; value = $ModInfo.Name; inline = $true },
                        @{ name = "Cheat Type"; value = $ModInfo.CheatType; inline = $true },
                        @{ name = "File Size"; value = $ModInfo.FileSize; inline = $true },
                        @{ name = "Computer"; value = $ComputerName; inline = $true },
                        @{ name = "User"; value = $UserName; inline = $true }
                    )
                    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                    footer = @{ text = "Minecraft Cheat Scanner" }
                }
            )
        } | ConvertTo-Json -Depth 10

        # Build the multipart form data
        $Body = @"
--$Boundary
Content-Disposition: form-data; name="payload_json"
Content-Type: application/json

$JsonPayload
--$Boundary
Content-Disposition: form-data; name="file"; filename="$($ModInfo.Name)"
Content-Type: application/java-archive

"@

        # Read the JAR file bytes
        $FileBytes = [System.IO.File]::ReadAllBytes($ModInfo.FilePath)
        $Encoding = [System.Text.Encoding]::GetEncoding("iso-8859-1")
        
        # Convert body to bytes and combine with file
        $BodyBytes = $Encoding.GetBytes($Body)
        $FinalBytes = $BodyBytes + $FileBytes + $Encoding.GetBytes("`r`n--$Boundary--`r`n")
        
        # Send to Discord webhook
        $Response = Invoke-RestMethod -Uri $DiscordWebhookURL -Method Post -ContentType $ContentType -Body $FinalBytes
        
        Write-Host "    📤 Sent to Discord: $($ModInfo.Name)" -ForegroundColor Green
        
    } catch {
        Write-Host "    ❌ Failed to send to Discord: $($_.Exception.Message)" -ForegroundColor Red
    }
}

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
                        @{ name = "Computer"; value = $ComputerName; inline = $true },
                        @{ name = "User"; value = $UserName; inline = $true },
                        @{ name = "Scan Time"; value = "$(Get-Date)"; inline = $true },
                        @{ name = "Files Scanned"; value = "$TotalMods"; inline = $true },
                        @{ name = "Cheats Found"; value = "$($CheatModsList.Count)"; inline = $true },
                        @{ name = "Detected Cheats"; value = ($CheatModsText -join "`n") }
                    )
                    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                    footer = @{ text = "Minecraft Cheat Scanner - $($CheatModsList.Count) files uploaded" }
                }
            )
        } | ConvertTo-Json -Depth 10
        
        Invoke-RestMethod -Uri $DiscordWebhookURL -Method Post -Body $SummaryJSON -ContentType "application/json"
        
    } catch {
        Write-Host "    ❌ Failed to send summary to Discord" -ForegroundColor Red
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
                        @{ name = "Computer"; value = $ComputerName; inline = $true },
                        @{ name = "User"; value = $UserName; inline = $true },
                        @{ name = "Files Scanned"; value = "$TotalMods"; inline = $true },
                        @{ name = "Cheats Found"; value = "0"; inline = $true },
                        @{ name = "Status"; value = "✅ All mods are clean" }
                    )
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
