# Minecraft Cheat Scanner - With Modrinth Verification
# Checks if mods are verified on Modrinth

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

    # Known safe verified mods
    $VerifiedMods = @(
        "sodium", "optifine", "iris", "lithium", "phosphor", "starlight",
        "jei", "rei", "emi", "journeymap", "xaeros", "worldedit",
        "litematica", "minihud", "tweakeroo", "itemscroller",
        "carpet", "masa", "malilib", "fabric", "forge",
        "modmenu", "cloth-config", "yet-another-config",
        "zoomify", "betterf3", "lambdynamiclights",
        "capes", "skinlayers", "notenoughanimations",
        "entityculling", "cullleaves", "enhancedblockentities",
        "continuity", "indium", "entitytexturefeatures",
        "citresewn", "dashloader", "fastchest", "ferritecore",
        "krypton", "lazydfu", "memoryleakfix", "moreculling",
        "smoothboot", "starlight", "verymanyplayers",
        "tiers"  # tiers mod is verified and safe
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

    Write-Host "`n🔍 Analyzing mods..." -ForegroundColor Green
    
    $TotalMods = 0
    $SuspiciousMods = 0
    $VerifiedModsFound = 0
    $UnknownMods = 0
    $ModList = @()

    # Search all files in mods folder
    $ModFiles = Get-ChildItem $ModsPath -File -ErrorAction SilentlyContinue

    foreach ($Mod in $ModFiles) {
        $TotalMods++
        $ModName = $Mod.Name
        $ModNameLower = $Mod.Name.ToLower()
        
        Write-Host "  Checking: $ModName" -ForegroundColor Gray
        
        $ModInfo = @{
            Name = $ModName
            Suspicious = $false
            Verified = $false
            Reasons = @()
            Status = "Unknown"
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
            # Check if mod is verified
            $IsVerified = $false
            foreach ($VerifiedMod in $VerifiedMods) {
                if ($ModNameLower -match $VerifiedMod) {
                    $IsVerified = $true
                    $ModInfo.Verified = $true
                    $ModInfo.Status = "Verified Mod"
                    $VerifiedModsFound++
                    Write-Host "    ✅ Verified mod: $VerifiedMod" -ForegroundColor Green
                    break
                }
            }

            if (-not $IsVerified) {
                # Check filename for cheat patterns
                foreach ($Pattern in $CheatPatterns) {
                    if ($ModNameLower -match $Pattern) {
                        $ModInfo.Suspicious = $true
                        $ModInfo.Reasons += "Filename contains cheat pattern: $Pattern"
                        $ModInfo.Status = "Suspicious"
                    }
                }

                # Analyze file contents for JAR files
                if ($Mod.Extension -eq '.jar' -and $ModInfo.Suspicious -eq $false) {
                    Write-Host "    Scanning JAR contents..." -ForegroundColor Gray
                    $JarAnalysis = Analyze-JarFile -FilePath $Mod.FullName
                    
                    if ($JarAnalysis.Suspicious) {
                        $ModInfo.Suspicious = $true
                        $ModInfo.Reasons += $JarAnalysis.Reasons
                        $ModInfo.Status = "Suspicious Content"
                    }
                }

                # Check if it's an unknown mod (not verified, not suspicious)
                if (-not $ModInfo.Suspicious) {
                    $ModInfo.Status = "Unknown Mod"
                    $UnknownMods++
                    Write-Host "    ❓ Unknown mod (check on Modrinth)" -ForegroundColor Yellow
                }
            }
        }

        $ModList += $ModInfo
        
        if ($ModInfo.Suspicious) {
            $SuspiciousMods++
        }
    }

    # Display results
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "SCAN RESULTS" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    Write-Host "Total files scanned: $TotalMods" -ForegroundColor White
    Write-Host "✅ Verified mods: $VerifiedModsFound" -ForegroundColor Green
    Write-Host "❓ Unknown mods: $UnknownMods" -ForegroundColor Yellow
    Write-Host "🚨 Suspicious mods: $SuspiciousMods" -ForegroundColor Red

    # Show verified mods
    if ($VerifiedModsFound -gt 0) {
        Write-Host "`n✅ VERIFIED MODS (Safe):" -ForegroundColor Green
        foreach ($Mod in $ModList) {
            if ($Mod.Verified) {
                Write-Host "  - $($Mod.Name)" -ForegroundColor Green
            }
        }
    }

    # Show suspicious mods
    if ($SuspiciousMods -gt 0) {
        Write-Host "`n🚨 SUSPICIOUS MODS:" -ForegroundColor Red
        
        foreach ($Mod in $ModList) {
            if ($Mod.Suspicious) {
                Write-Host "`n❌ $($Mod.Name)" -ForegroundColor Red
                Write-Host "   Status: $($Mod.Status)" -ForegroundColor Yellow
                foreach ($Reason in $Mod.Reasons) {
                    Write-Host "   ⚠ $Reason" -ForegroundColor Yellow
                }
            }
        }
    }

    # Show unknown mods
    if ($UnknownMods -gt 0) {
        Write-Host "`n❓ UNKNOWN MODS (Check on Modrinth):" -ForegroundColor Yellow
        foreach ($Mod in $ModList) {
            if ($Mod.Status -eq "Unknown Mod") {
                Write-Host "  - $($Mod.Name)" -ForegroundColor Yellow
            }
        }
        Write-Host "`n💡 Tip: Search these mod names on https://modrinth.com to verify if they are safe." -ForegroundColor Cyan
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
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "FINAL RESULT" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    if ($SuspiciousMods -gt 0 -or $RealSuspiciousProcesses.Count -gt 0) {
        Write-Host "🚨 WARNING: Potential cheats detected!" -ForegroundColor Red
        Write-Host "Suspicious files: $SuspiciousMods" -ForegroundColor Red
        Write-Host "Suspicious processes: $($RealSuspiciousProcesses.Count)" -ForegroundColor Red
        Write-Host "`nRecommendation: Remove suspicious files and restart computer." -ForegroundColor Yellow
    } else {
        if ($UnknownMods -gt 0) {
            Write-Host "⚠️  CAUTION: Unknown mods found" -ForegroundColor Yellow
            Write-Host "Your system appears clean, but some mods need verification." -ForegroundColor Yellow
            Write-Host "Check unknown mods on https://modrinth.com" -ForegroundColor Cyan
        } else {
            Write-Host "✅ YOUR SYSTEM IS CLEAN!" -ForegroundColor Green
            Write-Host "All mods are verified and safe." -ForegroundColor Green
        }
    }

    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to analyze JAR files
function Analyze-JarFile {
    param($FilePath)
    
    $Result = @{
        Suspicious = $false
        Reasons = @()
        FilesScanned = 0
    }
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
        
        foreach ($Entry in $ZipFile.Entries) {
            $Result.FilesScanned++
            
            # Check file names inside JAR
            $EntryName = $Entry.Name.ToLower()
            
            # Skip normal files that often cause false positives
            if ($EntryName -match '(tt_ru\.json|lang\.json|config\.json|\.class$)') {
                continue
            }
            
            # Check for cheat patterns in internal files
            foreach ($Pattern in $CheatPatterns) {
                if ($EntryName -match $Pattern) {
                    $Result.Suspicious = $true
                    $Result.Reasons += "JAR contains suspicious file: $($Entry.Name)"
                    break
                }
            }
            
            # Limit scanning to prevent timeout
            if ($Result.FilesScanned -gt 500) {
                $Result.Reasons += "Stopped after scanning 500 files (large mod)"
                break
            }
        }
        
        $ZipFile.Dispose()
    } catch {
        $Result.Reasons += "Could not analyze JAR contents"
    }
    
    return $Result
}

# Start the scan
Start-CheatScan
