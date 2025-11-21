# Minecraft Cheat Scanner - Complete Analysis
# Easy to understand for normal users

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

    # Words that are OK in normal mods (not cheats)
    $SafeWords = @(
        "hidden", "bypass", "exploit",  # Can appear in normal mods
        "tt_ru", "json", "config",      # Normal mod files
        "sodium", "optifine", "fabric", # Known legal mods
        "lithium", "phosphor", "iris"   # Performance mods
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
            Reasons = @()
            Type = "Unknown"
        }

        # Skip safe system files
        $IsSafeFile = $false
        foreach ($Safe in $SafePrograms) {
            if ($ModNameLower -match $Safe) {
                $IsSafeFile = $true
                Write-Host "    ✅ Safe system file" -ForegroundColor Green
                break
            }
        }

        if (-not $IsSafeFile) {
            # Check filename for cheat patterns
            foreach ($Pattern in $CheatPatterns) {
                if ($ModNameLower -match $Pattern) {
                    # Check if it's a false positive
                    $IsFalsePositive = $false
                    foreach ($SafeWord in $SafeWords) {
                        if ($ModNameLower -match $SafeWord) {
                            $IsFalsePositive = $true
                            break
                        }
                    }
                    
                    if (-not $IsFalsePositive) {
                        $ModInfo.Suspicious = $true
                        $ModInfo.Reasons += "Filename contains cheat pattern: $Pattern"
                    }
                }
            }

            # Analyze file contents for JAR files
            if ($Mod.Extension -eq '.jar') {
                Write-Host "    Scanning JAR contents..." -ForegroundColor Gray
                $JarAnalysis = Analyze-JarFile -FilePath $Mod.FullName
                
                if ($JarAnalysis.Suspicious) {
                    $ModInfo.Suspicious = $true
                    $ModInfo.Reasons += $JarAnalysis.Reasons
                }
            }

            # Analyze text files (JSON, configs)
            if ($Mod.Extension -match '\.(json|txt|cfg|config)$') {
                $TextAnalysis = Analyze-TextFile -FilePath $Mod.FullName
                if ($TextAnalysis.Suspicious) {
                    $ModInfo.Suspicious = $true
                    $ModInfo.Reasons += $TextAnalysis.Reasons
                }
            }

            # Check file size (suspicious if too small/large)
            if ($Mod.Extension -eq '.jar') {
                if ($Mod.Length -lt 1024) { # Less than 1KB
                    $ModInfo.Suspicious = $true
                    $ModInfo.Reasons += "Suspiciously small JAR file ($([math]::Round($Mod.Length/1KB, 2)) KB)"
                } elseif ($Mod.Length -gt 50MB) { # More than 50MB
                    $ModInfo.Suspicious = $true
                    $ModInfo.Reasons += "Unusually large JAR file ($([math]::Round($Mod.Length/1MB, 2)) MB)"
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
    
    # Show suspicious mods
    if ($SuspiciousMods -gt 0) {
        Write-Host "`n🚨 SUSPICIOUS FILES FOUND ($SuspiciousMods):" -ForegroundColor Red
        
        foreach ($Mod in $ModList) {
            if ($Mod.Suspicious) {
                Write-Host "`n❌ FILE: $($Mod.Name)" -ForegroundColor Red
                foreach ($Reason in $Mod.Reasons) {
                    Write-Host "   ⚠ $Reason" -ForegroundColor Yellow
                }
            }
        }
    } else {
        Write-Host "`n✅ No suspicious files found" -ForegroundColor Green
    }
    
    # Show clean mods count
    $CleanMods = $TotalMods - $SuspiciousMods
    if ($CleanMods -gt 0) {
        Write-Host "`n✅ Clean files: $CleanMods" -ForegroundColor Green
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

    # Check Recycle Bin
    Write-Host "`n🗑️  Checking Recycle Bin..." -ForegroundColor Green
    try {
        $Shell = New-Object -ComObject Shell.Application
        $RecycleBin = $Shell.NameSpace(0xA)
        $DeletedJars = 0
        
        foreach ($Item in $RecycleBin.Items()) {
            if ($Item.Name -match '\.jar$') {
                $DeletedJars++
            }
        }
        
        if ($DeletedJars -gt 0) {
            Write-Host "ℹ️  Found $DeletedJars JAR files in Recycle Bin" -ForegroundColor Yellow
        } else {
            Write-Host "✅ No JAR files in Recycle Bin" -ForegroundColor Green
        }
    } catch {
        Write-Host "ℹ️  Could not check Recycle Bin" -ForegroundColor Gray
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
        Write-Host "✅ YOUR SYSTEM IS CLEAN!" -ForegroundColor Green
        Write-Host "No cheat activity detected." -ForegroundColor Green
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

# Function to analyze text files
function Analyze-TextFile {
    param($FilePath)
    
    $Result = @{
        Suspicious = $false
        Reasons = @()
    }
    
    try {
        if ((Get-Item $FilePath).Length -lt 100000) { # Only read files under 100KB
            $Content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
            
            if ($Content) {
                $ContentLower = $Content.ToLower()
                
                # Check for cheat patterns in content
                foreach ($Pattern in $CheatPatterns) {
                    if ($ContentLower -match $Pattern) {
                        # Skip common false positives
                        if (-not ($FilePath -match 'tt_ru\.json' -and $Pattern -eq 'hidden')) {
                            $Result.Suspicious = $true
                            $Result.Reasons += "File contains cheat pattern: $Pattern"
                        }
                    }
                }
            }
        }
    } catch {
        # Skip files that can't be read
    }
    
    return $Result
}

# Start the scan
Start-CheatScan
