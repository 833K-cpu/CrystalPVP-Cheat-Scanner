# Minecraft Screenshare Scanner - Discord Bot Version
function Start-CheatScan {
    Write-Host "=== MINECRAFT SCREENSHARE SCANNER ===" -ForegroundColor Cyan
    Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

    # Auto-detect all Minecraft paths
    $DetectedPaths = @()
    
    # Standard paths
    $pathsToCheck = @(
        "$env:APPDATA\.minecraft",
        "$env:USERPROFILE\AppData\Roaming\.minecraft"
    )
    
    # Modrinth profiles
    $modrinthPath = "$env:APPDATA\ModrinthApp\profiles"
    if (Test-Path $modrinthPath) {
        $modrinthProfiles = Get-ChildItem $modrinthPath -Directory -ErrorAction SilentlyContinue
        foreach ($profile in $modrinthProfiles) {
            $pathsToCheck += $profile.FullName
        }
    }
    
    # Check all paths
    foreach ($path in $pathsToCheck) {
        if (Test-Path $path) {
            $DetectedPaths += $path
        }
    }
    
    if ($DetectedPaths.Count -eq 0) {
        Write-Host "❌ No Minecraft folders found automatically!" -ForegroundColor Red
        Write-Host "Please enter path manually:" -ForegroundColor Yellow
        $MinecraftPath = Read-Host "Minecraft folder path"
    }
    elseif ($DetectedPaths.Count -eq 1) {
        $MinecraftPath = $DetectedPaths[0]
        Write-Host "✅ Auto-selected: $MinecraftPath" -ForegroundColor Green
    }
    else {
        Write-Host "`n📁 Multiple Minecraft folders found:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $DetectedPaths.Count; $i++) {
            Write-Host "  $($i+1). $($DetectedPaths[$i])" -ForegroundColor Gray
        }
        $choice = Read-Host "`nSelect folder (1-$($DetectedPaths.Count))"
        if ($choice -match "^\d+$" -and [int]$choice -le $DetectedPaths.Count) {
            $MinecraftPath = $DetectedPaths[[int]$choice - 1]
        } else {
            $MinecraftPath = $DetectedPaths[0]
        }
    }

    $MinecraftPath = $MinecraftPath.Trim().Trim('"')

    if (-not (Test-Path $MinecraftPath)) {
        Write-Host "❌ Path does not exist: $MinecraftPath" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    Write-Host "`n🔍 Scanning: $MinecraftPath" -ForegroundColor Green

    # Enhanced cheat detection
    $KnownCheatMods = @(
        "osmium", "elytraboost", "cwe", "crystaloptimizer",
        "heroanchor", "anchoroptimizer", "ias", "interactivespeed", 
        "cookeymod", "reflex", "vulcan", "verus", "cwb"
    )

    $ModsPath = "$MinecraftPath\mods"
    
    if (-not (Test-Path $ModsPath)) {
        Write-Host "❌ No 'mods' folder found!" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    Write-Host "`n🕵️ Scanning for cheat mods..." -ForegroundColor Green
    
    $TotalMods = 0
    $CheatModsFound = 0
    $CheatModsList = @()
    $ComputerName = $env:COMPUTERNAME
    $UserName = $env:USERNAME

    try {
        $ModFiles = Get-ChildItem $ModsPath -Filter "*.jar" -ErrorAction Stop
    } catch {
        Write-Host "❌ Error accessing mods folder: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    foreach ($Mod in $ModFiles) {
        $TotalMods++
        $ModName = $Mod.Name
        $ModNameLower = $Mod.Name.ToLower()
        
        Write-Host "  Scanning: $ModName" -ForegroundColor Gray
        
        $DetectedCheats = @()
        foreach ($CheatMod in $KnownCheatMods) {
            if ($ModNameLower -match $CheatMod) {
                $DetectedCheats += $CheatMod
            }
        }

        if ($DetectedCheats.Count -gt 0) {
            $CheatModsFound++
            $ModInfo = @{
                Name = $ModName
                FilePath = $Mod.FullName
                FileSize = "$([math]::Round($Mod.Length/1KB, 2)) KB"
                CheatTypes = $DetectedCheats -join ", "
                FileSizeMB = [math]::Round($Mod.Length/1MB, 2)
                LastModified = $Mod.LastWriteTime
            }
            $CheatModsList += $ModInfo
            
            Write-Host "    🚨 CHEAT DETECTED: $($DetectedCheats -join ', ')" -ForegroundColor Red
        } else {
            Write-Host "    ✅ Clean" -ForegroundColor Green
        }
    }

    # Display results
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "SCREENSHARE SCAN RESULTS" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan
    
    Write-Host "📊 JAR files scanned: $TotalMods" -ForegroundColor White
    
    if ($CheatModsFound -gt 0) {
        Write-Host "🚨 CHEAT MODS FOUND: $CheatModsFound" -ForegroundColor Red
        
        foreach ($CheatMod in $CheatModsList) {
            Write-Host "`n❌ $($CheatMod.Name)" -ForegroundColor Red
            Write-Host "   📁 Type: $($CheatMod.CheatTypes)" -ForegroundColor Yellow
            Write-Host "   📦 Size: $($CheatMod.FileSize)" -ForegroundColor Gray
        }

        Write-Host "`n💡 Use the Discord Bot to download these files:" -ForegroundColor Cyan
        Write-Host "   Commands: /download_mod [filename] or /download_all" -ForegroundColor Cyan
        Write-Host "`n📋 Detected files:" -ForegroundColor Yellow
        foreach ($CheatMod in $CheatModsList) {
            Write-Host "   • $($CheatMod.Name)" -ForegroundColor White
        }
        
    } else {
        Write-Host "`n✅ NO CHEAT MODS DETECTED!" -ForegroundColor Green
        Write-Host "System appears clean." -ForegroundColor Green
    }

    Write-Host "`nScan completed: $(Get-Date)" -ForegroundColor Yellow
    Write-Host "Press Enter to exit..." -ForegroundColor Gray
    Read-Host
}

# Start scan
Start-CheatScan
