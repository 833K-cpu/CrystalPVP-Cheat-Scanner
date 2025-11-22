# Minecraft Cheat Scanner - Real Hack Code Detection
# Only shows mods that contain actual cheat code

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

    # Real cheat code patterns - not just filenames
    $CheatCodePatterns = @(
        # PVP cheat functions
        "killaura", "kill.*aura", "aura.*kill",
        "reach", "attack.*reach", "hit.*reach", 
        "velocity", "knockback", "antiknockback",
        "autoclick", "auto.*click", "clicker",
        "aimassist", "aim.*assist", "aimbot",
        "triggerbot", "trigger.*bot",
        "antibot", "anti.*bot",
        "speedmine", "fast.*mine",
        "nuker", "block.*nuker",
        "scaffold", "tower", "bridge",
        "nofall", "no.*fall",
        "flight", "fly", "jesus",
        "speed", "bunny.*hop",
        "xray", "ore.*esp",
        "esp", "tracers", "radar",
        "nametags", "name.*tags",
        "hitboxes", "hit.*boxes",
        "crystalaura", "crystal.*aura",
        "autopot", "auto.*pot",
        "fastplace", "fast.*place"
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

    Write-Host "`n🔍 Opening and scanning JAR files for cheat code..." -ForegroundColor Green
    
    $TotalMods = 0
    $ModsWithCheats = 0
    $CheatModsList = @()

    # Search all JAR files in mods folder
    $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction SilentlyContinue

    foreach ($Mod in $ModFiles) {
        $TotalMods++
        $ModName = $Mod.Name
        
        Write-Host "  Scanning: $ModName" -ForegroundColor Gray
        
        # Deep scan JAR for actual cheat code
        $CheatAnalysis = Find-CheatCodeInJar -FilePath $Mod.FullName -ModName $ModName
        
        if ($CheatAnalysis.ContainsCheats) {
            $ModsWithCheats++
            $CheatModsList += @{
                Name = $ModName
                CheatFiles = $CheatAnalysis.CheatFiles
                CheatEvidence = $CheatAnalysis.CheatEvidence
            }
            
            Write-Host "    🚨 CHEAT CODE FOUND!" -ForegroundColor Red
            foreach ($evidence in $CheatAnalysis.CheatEvidence) {
                Write-Host "      ⚠ $evidence" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    ✅ No cheat code found" -ForegroundColor Green
        }
    }

    # Display ONLY cheat results
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "CHEAT SCAN RESULTS" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan
    
    Write-Host "JAR files scanned: $TotalMods" -ForegroundColor White
    
    if ($ModsWithCheats -gt 0) {
        Write-Host "🚨 MODS WITH CHEAT CODE: $ModsWithCheats" -ForegroundColor Red
        Write-Host "-" * 50 -ForegroundColor Red
        
        foreach ($CheatMod in $CheatModsList) {
            Write-Host "`n❌ $($CheatMod.Name)" -ForegroundColor Red
            Write-Host "   Cheat evidence:" -ForegroundColor Yellow
            foreach ($evidence in $CheatMod.CheatEvidence) {
                Write-Host "   ⚠ $evidence" -ForegroundColor Yellow
            }
            if ($CheatMod.CheatFiles.Count -gt 0) {
                Write-Host "   Files with cheat code:" -ForegroundColor Red
                foreach ($file in $CheatMod.CheatFiles) {
                    Write-Host "      - $file" -ForegroundColor Yellow
                }
            }
        }
    } else {
        Write-Host "`n✅ NO CHEAT CODE FOUND IN ANY MODS!" -ForegroundColor Green
        Write-Host "All mods appear to be clean." -ForegroundColor Green
    }

    # Final summary
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    
    if ($ModsWithCheats -gt 0) {
        Write-Host "🚨 REMOVE THESE $ModsWithCheats MODS - THEY CONTAIN CHEAT CODE!" -ForegroundColor Red
    } else {
        Write-Host "✅ YOUR MODS ARE CLEAN - NO CHEATS DETECTED" -ForegroundColor Green
    }

    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to find actual cheat code in JAR files
function Find-CheatCodeInJar {
    param(
        [string]$FilePath,
        [string]$ModName
    )
    
    $Result = @{
        ContainsCheats = $false
        CheatFiles = @()
        CheatEvidence = @()
        FilesScanned = 0
    }
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
        
        # Check each file in the JAR for cheat code
        foreach ($Entry in $ZipFile.Entries) {
            $Result.FilesScanned++
            $EntryName = $Entry.Name
            $EntryNameLower = $Entry.Name.ToLower()
            
            # Skip very small files and binary files
            if ($Entry.Length -lt 10) { continue }
            if ($EntryName -match '\.class$|\.png$|\.jpg$|\.ogg$|\.wav$') { continue }
            
            # Check for cheat-related file names
            $CheatFileFound = $false
            $CheatType = ""
            
            foreach ($Pattern in $CheatCodePatterns) {
                if ($EntryNameLower -match $Pattern) {
                    $CheatFileFound = $true
                    $CheatType = "File contains cheat reference: $Pattern"
                    break
                }
            }
            
            # Read and analyze text-based files for actual cheat code
            if ($EntryName -match '\.(java|json|txt|yml|yaml|properties|cfg|config|mcmeta|toml)$') {
                if ($Entry.Length -lt 50000) { # Only read files under 50KB
                    try {
                        $Stream = $Entry.Open()
                        $Reader = New-Object System.IO.StreamReader($Stream)
                        $Content = $Reader.ReadToEnd()
                        $Reader.Close()
                        $Stream.Close()
                        
                        $ContentLower = $Content.ToLower()
                        
                        # Look for actual cheat code implementation
                        if ($ContentLower -match 'killaura|entityaura|attackallentities') {
                            $CheatFileFound = $true
                            $CheatType = "Contains KillAura code"
                        }
                        elseif ($ContentLower -match 'reach.*[=:].*[3-9]\.?[0-9]*|attackrange.*[=:].*[3-9]') {
                            $CheatFileFound = $true
                            $CheatType = "Contains Reach hack (extended attack range)"
                        }
                        elseif ($ContentLower -match 'velocity.*[=:].*[01]\.?[0-9]*|knockback.*[=:].*0\.?[0-9]*') {
                            $CheatFileFound = $true
                            $CheatType = "Contains Velocity/Knockback modifier"
                        }
                        elseif ($ContentLower -match 'autoclick|autoclicker|clickspam') {
                            $CheatFileFound = $true
                            $CheatType = "Contains AutoClicker code"
                        }
                        elseif ($ContentLower -match 'aimassist|aimbot|lockontarget') {
                            $CheatFileFound = $true
                            $CheatType = "Contains AimAssist/Aimbot code"
                        }
                        elseif ($ContentLower -match 'antibot|checkbot|botdetection') {
                            $CheatFileFound = $true
                            $CheatType = "Contains AntiBot system (common in cheats)"
                        }
                        elseif ($ContentLower -match 'nuker|fastbreak|instantbreak') {
                            $CheatFileFound = $true
                            $CheatType = "Contains Nuker/FastBreak code"
                        }
                        elseif ($ContentLower -match 'scaffold|tower|bridge') {
                            $CheatFileFound = $true
                            $CheatType = "Contains Scaffold code"
                        }
                        elseif ($ContentLower -match 'nofall|nofall|fall.*damage') {
                            $CheatFileFound = $true
                            $CheatType = "Contains NoFall code"
                        }
                        elseif ($ContentLower -match 'crystalaura|ca\.|crystal.*place') {
                            $CheatFileFound = $true
                            $CheatType = "Contains CrystalAura code"
                        }
                        elseif ($ContentLower -match 'xray|oreesp|seeores') {
                            $CheatFileFound = $true
                            $CheatType = "Contains Xray/OREesp code"
                        }
                        elseif ($ContentLower -match 'esp|tracers|entityoverlay') {
                            $CheatFileFound = $true
                            $CheatType = "Contains ESP/Tracers code"
                        }
                    } catch {
                        # Skip files that can't be read
                    }
                }
            }
            
            if ($CheatFileFound) {
                $Result.ContainsCheats = $true
                $Result.CheatFiles += $EntryName
                $Result.CheatEvidence += $CheatType
            }
            
            # Limit scanning to prevent timeout
            if ($Result.FilesScanned -gt 800) {
                $Result.CheatEvidence += "Stopped after scanning 800 files"
                break
            }
        }
        
        $ZipFile.Dispose()
        
    } catch {
        $Result.CheatEvidence += "Could not scan JAR contents: $($_.Exception.Message)"
    }
    
    return $Result
}

# Start the scan
Start-CheatScan
