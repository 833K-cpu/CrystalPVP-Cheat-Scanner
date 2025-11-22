# Minecraft Cheat Scanner - With Real Modrinth Verification
# Checks Modrinth API to verify mods

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
            ModrinthID = ""
            ModrinthURL = ""
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
            # Check filename for cheat patterns
            foreach ($Pattern in $CheatPatterns) {
                if ($ModNameLower -match $Pattern) {
                    $ModInfo.Suspicious = $true
                    $ModInfo.Reasons += "Filename contains cheat pattern: $Pattern"
                    $ModInfo.Status = "Suspicious"
                }
            }

            # Only check Modrinth for non-suspicious JAR files
            if ($Mod.Extension -eq '.jar' -and -not $ModInfo.Suspicious) {
                Write-Host "    Checking Modrinth API..." -ForegroundColor Gray
                $ModrinthCheck = Check-ModrinthAPI -ModFileName $ModName
                
                if ($ModrinthCheck.Found) {
                    $ModInfo.Verified = $true
                    $ModInfo.Status = "Verified on Modrinth"
                    $ModInfo.ModrinthID = $ModrinthCheck.ProjectID
                    $ModInfo.ModrinthURL = $ModrinthCheck.ProjectURL
                    $VerifiedModsFound++
                    Write-Host "    ✅ Verified on Modrinth: $($ModrinthCheck.ProjectName)" -ForegroundColor Green
                } else {
                    $ModInfo.Status = "Not on Modrinth"
                    $UnknownMods++
                    Write-Host "    ❓ Not found on Modrinth" -ForegroundColor Yellow
                }
            } elseif (-not $ModInfo.Suspicious) {
                $UnknownMods++
                Write-Host "    ❓ Unknown file type" -ForegroundColor Yellow
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
    Write-Host "✅ Verified on Modrinth: $VerifiedModsFound" -ForegroundColor Green
    Write-Host "❓ Not on Modrinth: $UnknownMods" -ForegroundColor Yellow
    Write-Host "🚨 Suspicious mods: $SuspiciousMods" -ForegroundColor Red

    # Show verified mods with Modrinth links
    if ($VerifiedModsFound -gt 0) {
        Write-Host "`n✅ MODS VERIFIED ON MODRINTH:" -ForegroundColor Green
        foreach ($Mod in $ModList) {
            if ($Mod.Verified) {
                Write-Host "  - $($Mod.Name)" -ForegroundColor Green
                if ($Mod.ModrinthURL) {
                    Write-Host "    🔗 $($Mod.ModrinthURL)" -ForegroundColor Blue
                }
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
        Write-Host "`n❓ FILES NOT FOUND ON MODRINTH:" -ForegroundColor Yellow
        foreach ($Mod in $ModList) {
            if ($Mod.Status -eq "Not on Modrinth" -or $Mod.Status -eq "Unknown file type") {
                Write-Host "  - $($Mod.Name)" -ForegroundColor Yellow
            }
        }
        Write-Host "`n💡 These files might be custom mods, outdated, or from other sources." -ForegroundColor Cyan
        Write-Host "   Check if they are safe before using them." -ForegroundColor Cyan
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
            Write-Host "⚠️  CAUTION: Some files not verified" -ForegroundColor Yellow
            Write-Host "No cheats detected, but $UnknownMods files are not on Modrinth." -ForegroundColor Yellow
            Write-Host "Make sure these files are from trusted sources." -ForegroundColor Cyan
        } else {
            Write-Host "✅ YOUR SYSTEM IS CLEAN!" -ForegroundColor Green
            Write-Host "All mods are verified on Modrinth and safe." -ForegroundColor Green
        }
    }

    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to check Modrinth API
function Check-ModrinthAPI {
    param(
        [string]$ModFileName
    )
    
    $Result = @{
        Found = $false
        ProjectID = ""
        ProjectName = ""
        ProjectURL = ""
    }
    
    try {
        # Extract potential mod name from filename
        $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($ModFileName)
        
        # Remove version numbers and other common patterns
        $CleanName = $BaseName -replace '[-_]\d+\.\d+\.?\d*.*$', '' -replace '-\d+\.\d+.*$', '' -replace '[-_]fabric$', '' -replace '[-_]forge$', ''
        
        # Try to search Modrinth API
        $SearchURL = "https://api.modrinth.com/v2/search?query=`"$CleanName`"&facets=[[`"project_type:mod`"]]&limit=1"
        
        Write-Host "    Searching for: $CleanName" -ForegroundColor DarkGray
        
        $Headers = @{
            'User-Agent' = 'Minecraft-Cheat-Scanner/1.0'
        }
        
        $SearchResponse = Invoke-RestMethod -Uri $SearchURL -Headers $Headers -Method GET
        
        if ($SearchResponse.hits.Count -gt 0) {
            $Project = $SearchResponse.hits[0]
            $Result.Found = $true
            $Result.ProjectID = $Project.project_id
            $Result.ProjectName = $Project.title
            $Result.ProjectURL = "https://modrinth.com/mod/$($Project.slug)"
        }
        
    } catch {
        Write-Host "    ⚠ Could not check Modrinth API" -ForegroundColor Yellow
    }
    
    return $Result
}

# Function to analyze JAR files for suspicious content
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
