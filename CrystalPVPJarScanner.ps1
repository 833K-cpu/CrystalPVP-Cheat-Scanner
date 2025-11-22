# Minecraft Cheat Scanner - Deep JAR Content Analysis
# Opens JAR files and searches for cheat code

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

    # Cheat detection patterns
    $CheatPatterns = @(
        # Known cheat clients
        "wurst", "sigma", "impact", "liquidbounce", "raven", "zenith",
        "novoline", "tenacity", "lambda", "gamesense", "phobos", "konas",
        "rusherhack", "future", "pyro", "wolfram", "w\+we", "salhack",
        
        # Cheat functions
        "killaura", "velocity", "antiknockback", "reach", "autoclicker",
        "crystalaura", "hitboxes", "aimassist", "triggerbot", "antibot",
        "autopot", "speedmine", "scaffold", "nofall", "nuker", "xray",
        "cheat", "hack", "client", "ghost", "phantom"
    )

    # Known safe system programs
    $SafePrograms = @(
        "nvsphelper", "discord", "obs", "overwolf",
        "teamspeak", "mumble", "nvidia", "amd", "intel"
    )

    # Scan mods folder
    $ModsPath = "$MinecraftPath\mods"
    
    if (-not (Test-Path $ModsPath)) {
        Write-Host "❌ No 'mods' folder found!" -ForegroundColor Red
        Write-Host "Make sure you entered the correct path." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit
    }

    Write-Host "`n🔍 Analyzing mods (deep scan)..." -ForegroundColor Green
    
    $TotalMods = 0
    $SuspiciousMods = 0
    $CleanMods = 0
    $ModList = @()

    # Search all files in mods folder
    $ModFiles = Get-ChildItem $ModsPath -File -ErrorAction SilentlyContinue

    foreach ($Mod in $ModFiles) {
        $TotalMods++
        $ModName = $Mod.Name
        $ModNameLower = $Mod.Name.ToLower()
        
        Write-Host "`n  Scanning: $ModName" -ForegroundColor White
        
        $ModInfo = @{
            Name = $ModName
            Suspicious = $false
            Reasons = @()
            Status = "Checking..."
            CheatCodeFound = $false
            InternalFiles = @()
        }

        # Skip safe system files
        $IsSafeFile = $false
        foreach ($Safe in $SafePrograms) {
            if ($ModNameLower -match $Safe) {
                $IsSafeFile = $true
                $ModInfo.Status = "Safe System File"
                Write-Host "    ✅ Safe system file" -ForegroundColor Green
                break
            }
        }

        if (-not $IsSafeFile) {
            # Check filename for cheat patterns first
            $FilenameSuspicious = $false
            foreach ($Pattern in $CheatPatterns) {
                if ($ModNameLower -match $Pattern) {
                    $FilenameSuspicious = $true
                    $ModInfo.Reasons += "Suspicious filename pattern: $Pattern"
                    break
                }
            }

            # Deep scan JAR files
            if ($Mod.Extension -eq '.jar') {
                Write-Host "    Opening JAR file..." -ForegroundColor Gray
                $DeepAnalysis = Analyze-JarDeep -FilePath $Mod.FullName -ModName $ModName
                
                if ($DeepAnalysis.Suspicious) {
                    $ModInfo.Suspicious = $true
                    $ModInfo.CheatCodeFound = $true
                    $ModInfo.Reasons += $DeepAnalysis.Reasons
                    $ModInfo.InternalFiles = $DeepAnalysis.SuspiciousFiles
                    $ModInfo.Status = "CHEAT CODE FOUND"
                    
                    Write-Host "    🚨 CHEAT CODE DETECTED!" -ForegroundColor Red
                    foreach ($file in $DeepAnalysis.SuspiciousFiles) {
                        Write-Host "      ⚠ $file" -ForegroundColor Yellow
                    }
                } elseif ($FilenameSuspicious) {
                    $ModInfo.Suspicious = $true
                    $ModInfo.Status = "Suspicious filename"
                    Write-Host "    ⚠ Suspicious filename" -ForegroundColor Yellow
                } else {
                    $ModInfo.Status = "Clean"
                    $CleanMods++
                    Write-Host "    ✅ Clean mod" -ForegroundColor Green
                }
            } else {
                if ($FilenameSuspicious) {
                    $ModInfo.Suspicious = $true
                    $ModInfo.Status = "Suspicious filename"
                    Write-Host "    ⚠ Suspicious filename" -ForegroundColor Yellow
                } else {
                    $ModInfo.Status = "Unknown file type"
                    Write-Host "    ❓ Unknown file type" -ForegroundColor Gray
                }
            }
        }

        $ModList += $ModInfo
        
        if ($ModInfo.Suspicious) {
            $SuspiciousMods++
        }
    }

    # Display results
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "DEEP SCAN RESULTS" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan
    
    Write-Host "Total files scanned: $TotalMods" -ForegroundColor White
    Write-Host "✅ Clean mods: $CleanMods" -ForegroundColor Green
    Write-Host "🚨 Suspicious mods: $SuspiciousMods" -ForegroundColor Red

    # Show suspicious mods with detailed cheat evidence
    if ($SuspiciousMods -gt 0) {
        Write-Host "`n🚨 CHEATS DETECTED:" -ForegroundColor Red
        
        foreach ($Mod in $ModList) {
            if ($Mod.Suspicious) {
                Write-Host "`n❌ $($Mod.Name)" -ForegroundColor Red
                Write-Host "   Status: $($Mod.Status)" -ForegroundColor Yellow
                
                foreach ($Reason in $Mod.Reasons) {
                    Write-Host "   ⚠ $Reason" -ForegroundColor Yellow
                }
                
                if ($Mod.CheatCodeFound -and $Mod.InternalFiles.Count -gt 0) {
                    Write-Host "   🔍 Cheat evidence found in:" -ForegroundColor Red
                    foreach ($file in $Mod.InternalFiles) {
                        Write-Host "      - $file" -ForegroundColor Yellow
                    }
                }
            }
        }
    }

    # Show clean mods
    if ($CleanMods -gt 0) {
        Write-Host "`n✅ CLEAN MODS:" -ForegroundColor Green
        foreach ($Mod in $ModList) {
            if (-not $Mod.Suspicious -and $Mod.Status -eq "Clean") {
                Write-Host "  - $($Mod.Name)" -ForegroundColor Green
            }
        }
    }

    # Scan running processes
    Write-Host "`n🔍 Checking running programs..." -ForegroundColor Green
    
    $SuspiciousProcesses = Get-Process | Where-Object { 
        $_.ProcessName -match ($CheatPatterns -join '|')
    }

    $SafeProcesses = $SuspiciousProcesses | Where-Object {
        $ProcName = $_.ProcessName.ToLower()
        $SafePrograms | Where-Object { $ProcName -match $_ }
    }

    $RealSuspiciousProcesses = $SuspiciousProcesses | Where-Object {
        $ProcName = $_.ProcessName.ToLower()
        -not ($SafePrograms | Where-Object { $ProcName -match $_ })
    }

    if ($RealSuspiciousProcesses.Count -gt 0) {
        Write-Host "❌ Suspicious programs running:" -ForegroundColor Red
        foreach ($Proc in $RealSuspiciousProcesses) {
            Write-Host "  - $($Proc.ProcessName)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✅ No suspicious programs found" -ForegroundColor Green
    }

    # Final summary
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "FINAL RESULT" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan
    
    if ($SuspiciousMods -gt 0) {
        Write-Host "🚨 CHEATS FOUND IN $SuspiciousMods MODS!" -ForegroundColor Red
        Write-Host "Remove these mods immediately!" -ForegroundColor Red
    } else {
        Write-Host "✅ YOUR SYSTEM IS CLEAN!" -ForegroundColor Green
        Write-Host "No cheat code detected in any mods." -ForegroundColor Green
    }

    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function for deep JAR analysis - searches for actual cheat code
function Analyze-JarDeep {
    param(
        [string]$FilePath,
        [string]$ModName
    )
    
    $Result = @{
        Suspicious = $false
        Reasons = @()
        SuspiciousFiles = @()
        FilesScanned = 0
    }
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
        
        # Special cheat detection for specific mods
        $ModNameLower = $ModName.ToLower()
        
        # Check each file in the JAR
        foreach ($Entry in $ZipFile.Entries) {
            $Result.FilesScanned++
            $EntryName = $Entry.Name
            $EntryNameLower = $Entry.Name.ToLower()
            
            # Skip very small files and common files
            if ($Entry.Length -lt 10) { continue }
            if ($EntryName -match 'META-INF|\.class$|\.png$|\.jpg$|\.ogg$') { continue }
            
            # Check for suspicious file names
            $SuspiciousFile = $false
            $CheatEvidence = ""
            
            foreach ($Pattern in $CheatPatterns) {
                if ($EntryNameLower -match $Pattern) {
                    $SuspiciousFile = $true
                    $CheatEvidence = "Contains '$Pattern' in filename"
                    break
                }
            }
            
            # Read and analyze text-based files for cheat code
            if ($EntryName -match '\.(java|json|txt|yml|yaml|properties|cfg|config|mcmeta)$') {
                if ($Entry.Length -lt 100000) { # Only read files under 100KB
                    try {
                        $Stream = $Entry.Open()
                        $Reader = New-Object System.IO.StreamReader($Stream)
                        $Content = $Reader.ReadToEnd()
                        $Reader.Close()
                        $Stream.Close()
                        
                        $ContentLower = $Content.ToLower()
                        
                        # Look for actual cheat code patterns
                        if ($ContentLower -match 'killaura|reach|velocity|antiknockback|autoclick') {
                            $SuspiciousFile = $true
                            $CheatEvidence = "Contains cheat code: $($Matches[0])"
                        }
                        elseif ($ContentLower -match 'bypass.*cheat|cheat.*bypass') {
                            $SuspiciousFile = $true
                            $CheatEvidence = "Contains cheat bypass code"
                        }
                        elseif ($ContentLower -match 'ghost.*client|client.*ghost') {
                            $SuspiciousFile = $true
                            $CheatEvidence = "Contains ghost client reference"
                        }
                    } catch {
                        # Skip files that can't be read
                    }
                }
            }
            
            if ($SuspiciousFile) {
                $Result.Suspicious = $true
                $Result.SuspiciousFiles += "$EntryName ($CheatEvidence)"
            }
            
            # Limit scanning to prevent timeout
            if ($Result.FilesScanned -gt 1000) {
                $Result.Reasons += "Deep scan completed (1000 files checked)"
                break
            }
        }
        
        $ZipFile.Dispose()
        
        # Special checks for specific mod types
        if ($ModNameLower -match 'antighost') {
            # AntiGhost should not contain actual cheat code
            if ($Result.Suspicious) {
                $Result.Reasons += "AntiGhost mod contains suspicious code (might be fake AntiGhost)"
            }
        }
        
        if ($ModNameLower -match 'cookeymod') {
            # Check if this is a real CookeyMod or contains cheats
            $Result.Reasons += "CookeyMod scanned - checking for hidden cheats"
        }
        
        if ($ModNameLower -match 'crosshairaddons') {
            # Crosshair mods can sometimes contain aim assist
            $Result.Reasons += "Crosshair mod scanned for aim assist features"
        }
        
        if ($ModNameLower -match 'dontuntogglesprint') {
            # Usually safe, but check for hidden features
            $Result.Reasons += "Sprint mod scanned for speed hacks"
        }
        
        if ($ModNameLower -match 'osmium') {
            # Osmium is usually safe, but verify
            if (-not $Result.Suspicious) {
                $Result.Reasons += "Osmium appears to be clean"
            }
        }
        
    } catch {
        $Result.Reasons += "Could not deeply analyze JAR: $($_.Exception.Message)"
    }
    
    return $Result
}

# Start the scan
Start-CheatScan
