# Crystal PVP Cheat Scanner with Advanced Detection
# Checks mod contents, not just filenames

function Start-CheatScan {
    Write-Host "=== Crystal PVP Cheat Scanner - Advanced Analysis ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    # Ask user for Minecraft path
    Write-Host "`nPlease enter your Minecraft .minecraft folder path:" -ForegroundColor White
    Write-Host "Examples:" -ForegroundColor Gray
    Write-Host "  - Default: C:\Users\YourName\AppData\Roaming\.minecraft" -ForegroundColor Gray
    Write-Host "  - MultiMC: C:\Users\YourName\Desktop\MultiMC\instances\YourInstance\.minecraft" -ForegroundColor Gray
    Write-Host "  - Lunar Client: C:\Users\YourName\.lunarclient\offline\1.8\.minecraft" -ForegroundColor Gray
    Write-Host "  - Badlion Client: C:\Users\YourName\AppData\Roaming\.badlionclient\.minecraft" -ForegroundColor Gray
    Write-Host "  - Modrinth: C:\Users\YourName\AppData\Roaming\ModrinthApp\profiles\YourProfile" -ForegroundColor Gray
    Write-Host "`nNOTE: Enter the path that CONTAINS the 'mods' folder, not the mods folder itself!" -ForegroundColor Yellow

    $MinecraftPath = Read-Host "`nEnter Minecraft path"

    # Validate path
    if (-not (Test-Path $MinecraftPath)) {
        Write-Host "ERROR: Path does not exist: $MinecraftPath" -ForegroundColor Red
        Write-Host "Please check the path and try again." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit
    }

    # Check if user entered mods folder directly
    if ($MinecraftPath -match '\\mods$') {
        Write-Host "WARNING: You entered the mods folder directly." -ForegroundColor Yellow
        Write-Host "Using parent directory instead..." -ForegroundColor Yellow
        $MinecraftPath = Split-Path $MinecraftPath -Parent
    }

    Write-Host "`nUsing Minecraft path: $MinecraftPath" -ForegroundColor Green

    $ScanResults = [System.Collections.ArrayList]@()
    $AllMods = [System.Collections.ArrayList]@()
    $SuspiciousMods = [System.Collections.ArrayList]@()
    $CheatDetected = $false
    $DeletedJarsFound = $false

    # Advanced cheat detection patterns
    $CheatPatterns = @(
        # Popular PVP Clients
        "wurst", "sigma", "impact", "liquidbounce", "raven", "zenith",
        "novoline", "tenacity", "lambda", "gamesense", "phobos", "konas",
        "rusherhack", "future", "pyro", "wolfram", "w\+we", "salhack",
        
        # PVP-specific modules
        "killaura", "velocity", "antiknockback", "reach", "autoclicker",
        "crystalpvp", "crystalaura", "crystalware", "pvpoptifine",
        "hitboxes", "aimassist", "triggerbot", "antibot", "autopot",
        "speedmine", "scaffold", "nofall", "sprint", "fastplace",
        
        # Obfuscated names
        "client", "cheat", "hack", "utility", "pvp", "ghost", "phantom",
        "clicker", "bot", "assist", "macro", "helper", "enhancement"
    )

    # Suspicious code patterns and strings
    $SuspiciousCodePatterns = @(
        "bypass", "exploit", "inject", "crack", "paid", "premium",
        "undetectable", "hidden", "ghost", "phantom", "spoofer",
        "nocheat", "anticheat", "reach", "velocity", "killaura",
        "autoclick", "aimbot", "triggerbot", "hitbox", "nofall",
        "speedmine", "scaffold", "xray", "fullbright", "nametags",
        "esp", "tracers", "radar", "freecam", "phase", "nuker"
    )

    # Files/Processes to IGNORE (false positives)
    $IgnorePatterns = @(
        "nvsphelper",    # NVIDIA ShadowPlay
        "discord",       # Discord
        "obs",           # OBS Studio
        "overwolf",      # Overwolf
        "teamspeak",     # TeamSpeak
        "mumble",        # Mumble
        "nvidia",        # NVIDIA
        "amd",           # AMD
        "intel"          # Intel
    )

    # Minecraft directories to scan
    $MinecraftPaths = @(
        "$MinecraftPath\mods",
        "$MinecraftPath\versions", 
        "$MinecraftPath\libraries",
        "$MinecraftPath\shaderpacks"
    )

    # Function to analyze JAR file contents
    function Analyze-JarContent {
        param($FilePath)
        
        $AnalysisResult = @{
            Suspicious = $false
            Reasons = @()
            FileSize = (Get-Item $FilePath).Length
            EntriesScanned = 0
        }
        
        try {
            # Use .NET Zip library to read JAR contents
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
            
            foreach ($Entry in $ZipFile.Entries) {
                $AnalysisResult.EntriesScanned++
                
                # Check file extensions in JAR
                if ($Entry.Name -match '\.(class|java|json|txt|yml|yaml|properties)$') {
                    # Check filename patterns
                    foreach ($Pattern in $SuspiciousCodePatterns) {
                        if ($Entry.Name -match $Pattern) {
                            $AnalysisResult.Suspicious = $true
                            $AnalysisResult.Reasons += "Suspicious file in JAR: $($Entry.Name) (Pattern: $Pattern)"
                        }
                    }
                    
                    # For text files, read and check content
                    if ($Entry.Name -match '\.(json|txt|yml|yaml|properties)$' -and $Entry.Length -lt 100000) {
                        try {
                            $Stream = $Entry.Open()
                            $Reader = New-Object System.IO.StreamReader($Stream)
                            $Content = $Reader.ReadToEnd()
                            $Reader.Close()
                            $Stream.Close()
                            
                            foreach ($CodePattern in $SuspiciousCodePatterns) {
                                if ($Content -match $CodePattern) {
                                    $AnalysisResult.Suspicious = $true
                                    $AnalysisResult.Reasons += "Suspicious content in $($Entry.Name): '$CodePattern'"
                                }
                            }
                        } catch {
                            # Skip files that can't be read
                        }
                    }
                }
                
                # Limit scanning to prevent timeout
                if ($AnalysisResult.EntriesScanned -gt 1000) {
                    $AnalysisResult.Reasons += "Stopped scanning after 1000 entries (large file)"
                    break
                }
            }
            
            $ZipFile.Dispose()
        } catch {
            $AnalysisResult.Reasons += "Could not analyze JAR contents: $($_.Exception.Message)"
        }
        
        return $AnalysisResult
    }

    # Function to check for recently deleted .jar files
    function Search-DeletedJarFiles {
        Write-Host "`nSearching for recently deleted .jar files..." -ForegroundColor Magenta
        
        $DeletedJars = [System.Collections.ArrayList]@()
        $OneHourAgo = (Get-Date).AddHours(-1)
        
        # Check Recycle Bin for deleted .jar files
        Write-Host "Checking Recycle Bin..." -ForegroundColor Yellow
        try {
            $Shell = New-Object -ComObject Shell.Application
            $RecycleBin = $Shell.NameSpace(0xA)  # Recycle Bin
            
            foreach ($Item in $RecycleBin.Items()) {
                if ($Item.Name -match '\.jar$') {
                    $DeletedDate = $Item.ModifyDate
                    if ($DeletedDate -gt $OneHourAgo) {
                        $Result = "DELETED_JAR: $($Item.Name) was deleted at $DeletedDate (Location: Recycle Bin)"
                        [void]$DeletedJars.Add($Result)
                        $script:DeletedJarsFound = $true
                        Write-Host "! Recently deleted .jar: $($Item.Name)" -ForegroundColor Red
                    }
                }
            }
        } catch {
            Write-Host "Recycle Bin access limited" -ForegroundColor Yellow
        }
        
        return $DeletedJars
    }

    # Scan Minecraft directories for active cheats
    Write-Host "`nScanning Minecraft directories for active cheats..." -ForegroundColor Green
    $FilesScanned = 0
    $ModsAnalyzed = 0
    
    foreach ($Path in $MinecraftPaths) {
        if (Test-Path $Path) {
            Write-Host "Checking: $Path"
            try {
                $Items = Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                    $_.Extension -match '\.(jar|exe|zip|rar|7z)$'
                }
                
                foreach ($Item in $Items) {
                    $FilesScanned++
                    $FileName = $Item.Name.ToLower()
                    $FullPath = $Item.FullName
                    
                    # Skip ignored files (false positives)
                    $ShouldIgnore = $false
                    foreach ($IgnorePattern in $IgnorePatterns) {
                        if ($FileName -match $IgnorePattern) {
                            $ShouldIgnore = $true
                            Write-Host "  [IGNORED] $($Item.Name) (safe system file)" -ForegroundColor Gray
                            break
                        }
                    }
                    
                    if (-not $ShouldIgnore) {
                        Write-Host "  Analyzing: $($Item.Name)" -ForegroundColor White
                        
                        $ModInfo = @{
                            Name = $Item.Name
                            Path = $FullPath
                            Size = "$([math]::Round($Item.Length/1KB, 2)) KB"
                            Suspicious = $false
                            Reasons = @()
                            Analysis = $null
                        }
                        
                        # Check filename patterns first
                        foreach ($Pattern in $CheatPatterns) {
                            if ($FileName -match $Pattern) {
                                $ModInfo.Suspicious = $true
                                $ModInfo.Reasons += "Filename matches cheat pattern: $Pattern"
                            }
                        }
                        
                        # Deep analysis for JAR files
                        if ($Item.Extension -eq '.jar') {
                            $ModsAnalyzed++
                            $Analysis = Analyze-JarContent -FilePath $FullPath
                            $ModInfo.Analysis = $Analysis
                            
                            if ($Analysis.Suspicious) {
                                $ModInfo.Suspicious = $true
                                $ModInfo.Reasons += $Analysis.Reasons
                            }
                            
                            Write-Host "    Scanned $($Analysis.EntriesScanned) entries" -ForegroundColor Gray
                        }
                        
                        # Check file size (very small or very large JARs can be suspicious)
                        if ($Item.Extension -eq '.jar') {
                            if ($Item.Length -lt 1024) { # Less than 1KB
                                $ModInfo.Suspicious = $true
                                $ModInfo.Reasons += "Suspiciously small JAR file ($([math]::Round($Item.Length/1KB, 2)) KB)"
                            } elseif ($Item.Length -gt 50MB) { # More than 50MB
                                $ModInfo.Suspicious = $true
                                $ModInfo.Reasons += "Unusually large JAR file ($([math]::Round($Item.Length/1MB, 2)) MB)"
                            }
                        }
                        
                        [void]$AllMods.Add($ModInfo)
                        
                        if ($ModInfo.Suspicious) {
                            [void]$SuspiciousMods.Add($ModInfo)
                            $script:CheatDetected = $true
                        }
                    }
                }
            } catch {
                Write-Host "Error scanning path" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Path not found: $Path" -ForegroundColor Gray
        }
    }

    Write-Host "`nFiles scanned: $FilesScanned" -ForegroundColor Gray
    Write-Host "JAR files analyzed: $ModsAnalyzed" -ForegroundColor Gray

    # Display scan results
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "SCAN RESULTS" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan
    
    # Show suspicious mods with detailed analysis
    if ($SuspiciousMods.Count -gt 0) {
        Write-Host "`n🚨 SUSPICIOUS MODS FOUND ($($SuspiciousMods.Count)):" -ForegroundColor Red
        Write-Host "-" * 50 -ForegroundColor Red
        
        foreach ($Mod in $SuspiciousMods) {
            Write-Host "`nMOD: $($Mod.Name)" -ForegroundColor Red
            Write-Host "Size: $($Mod.Size)" -ForegroundColor Yellow
            Write-Host "Path: $($Mod.Path)" -ForegroundColor Gray
            
            foreach ($Reason in $Mod.Reasons) {
                Write-Host "  ⚠ $Reason" -ForegroundColor Yellow
            }
            
            if ($Mod.Analysis -and $Mod.Analysis.EntriesScanned -gt 0) {
                Write-Host "  Scanned $($Mod.Analysis.EntriesScanned) internal files" -ForegroundColor Gray
            }
            
            Write-Host "-" * 40 -ForegroundColor DarkGray
        }
    } else {
        Write-Host "`n✅ No suspicious mods detected" -ForegroundColor Green
    }
    
    # Show clean mods
    $CleanMods = $AllMods | Where-Object { -not $_.Suspicious }
    if ($CleanMods.Count -gt 0) {
        Write-Host "`n✅ CLEAN MODS ($($CleanMods.Count)):" -ForegroundColor Green
        foreach ($Mod in $CleanMods) {
            Write-Host "  ✓ $($Mod.Name) ($($Mod.Size))" -ForegroundColor Green
        }
    }

    # Scan running processes
    Write-Host "`nScanning running processes..." -ForegroundColor Green
    $Processes = Get-Process | Where-Object { 
        $_.ProcessName -match ($CheatPatterns -join '|')
    }

    foreach ($Proc in $Processes) {
        # Check if process should be ignored
        $ShouldIgnore = $false
        foreach ($IgnorePattern in $IgnorePatterns) {
            if ($Proc.ProcessName -match $IgnorePattern) {
                $ShouldIgnore = $true
                Write-Host "Ignored (safe process): $($Proc.ProcessName)" -ForegroundColor Gray
                break
            }
        }
        
        if (-not $ShouldIgnore) {
            $Result = "SUSPICIOUS_PROCESS: $($Proc.ProcessName) (PID: $($Proc.Id))"
            [void]$ScanResults.Add($Result)
            $script:CheatDetected = $true
            Write-Host "! Suspicious process: $($Proc.ProcessName)" -ForegroundColor Red
        }
    }

    # Search for deleted .jar files
    $DeletedJarResults = Search-DeletedJarFiles
    if ($DeletedJarsFound) {
        $ScanResults.AddRange($DeletedJarResults)
    }

    # Generate comprehensive report
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "SCAN SUMMARY" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan
    Write-Host "Minecraft Path: $MinecraftPath" -ForegroundColor Gray
    Write-Host "Total files scanned: $FilesScanned" -ForegroundColor Gray
    Write-Host "JAR files analyzed: $ModsAnalyzed" -ForegroundColor Gray
    Write-Host "Clean mods: $($CleanMods.Count)" -ForegroundColor Green
    Write-Host "Suspicious mods: $($SuspiciousMods.Count)" -ForegroundColor Red

    if ($CheatDetected -or $DeletedJarsFound) {
        Write-Host "`n!!! CHEAT ACTIVITY DETECTED !!!" -ForegroundColor Red -BackgroundColor White
        
        if ($CheatDetected) {
            Write-Host "Suspicious mods found: $($SuspiciousMods.Count)" -ForegroundColor Red
        }
        
        if ($DeletedJarsFound) {
            Write-Host "Deleted .jar Files: $($DeletedJarResults.Count)" -ForegroundColor Red
        }
        
        # Save detailed report
        $Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $ReportFile = "cheat_scan_$Timestamp.txt"
        
        $ReportHeader = @"
Crystal PVP Cheat Scan - Advanced Analysis
Generated: $(Get-Date)
Minecraft Path: $MinecraftPath
Files Scanned: $FilesScanned
JAR Files Analyzed: $ModsAnalyzed

SUSPICIOUS MODS FOUND:
"@
        
        $ReportHeader | Out-File $ReportFile
        foreach ($Mod in $SuspiciousMods) {
            "`nMOD: $($Mod.Name)" | Out-File $ReportFile -Append
            "Size: $($Mod.Size)" | Out-File $ReportFile -Append
            "Path: $($Mod.Path)" | Out-File $ReportFile -Append
            "Reasons:" | Out-File $ReportFile -Append
            foreach ($Reason in $Mod.Reasons) {
                "  - $Reason" | Out-File $ReportFile -Append
            }
            "`n" + "-"*50 | Out-File $ReportFile -Append
        }
        
        Write-Host "`nDetailed report saved: $ReportFile" -ForegroundColor Yellow
        
    } else {
        Write-Host "`n✅ No cheat activity detected" -ForegroundColor Green
    }

    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Start the scan
Start-CheatScan
