# Crystal PVP Cheat Scanner with .jar File Detection
# Advanced detection for PVP cheat clients and deleted .jar files

Write-Host "=== Crystal PVP Cheat Scanner with .jar Analysis ===" -ForegroundColor Cyan
Write-Host "Scan started: $(Get-Date)" -ForegroundColor Yellow

$ScanResults = [System.Collections.ArrayList]@()
$CheatDetected = $false
$DeletedJarsFound = $false

# Comprehensive PVP cheat patterns
$CheatPatterns = @(
    # Popular PVP Clients
    "wurst", "sigma", "impact", "liquidbounce", "raven", "zenith",
    "novoline", "tenacity", "lambda", "gamesense", "phobos", "konas",
    "rusherhack", "future", "pyro", "wolfram", "w+we", "salhack",
    
    # PVP-specific modules
    "killaura", "velocity", "antiknockback", "reach", "autoclicker",
    "crystalpvp", "crystalaura", "crystalware", "pvpoptifine",
    "hitboxes", "aimassist", "triggerbot", "antibot", "autopot",
    "speedmine", "scaffold", "nofall", "sprint", "fastplace",
    
    # Obfuscated names
    "client", "cheat", "hack", "utility", "pvp", "ghost", "phantom",
    "clicker", "bot", "assist", "macro", "helper", "enhancement"
)

# Additional suspicious keywords
$SuspiciousKeywords = @(
    "bypass", "exploit", "inject", "crack", "paid", "premium",
    "undetectable", "hidden", "ghost", "phantom", "spoofer"
)

# Minecraft directories to scan
$MinecraftPaths = @(
    "$env:APPDATA\.minecraft\mods",
    "$env:APPDATA\.minecraft\versions", 
    "$env:APPDATA\.minecraft\client",
    "$env:APPDATA\.minecraft\libraries",
    "$env:APPDATA\.minecraft\shaderpacks",
    "$env:USERPROFILE\AppData\Roaming\.minecraft\mods",
    "$env:USERPROFILE\Documents\Minecraft",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop"
)

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
            if ($Item.Name -match '\.jar$' -or $Item.Name -match '\.jar\.\w+$') {
                $DeletedDate = $Item.ModifyDate
                if ($DeletedDate -gt $OneHourAgo) {
                    $Result = "DELETED_JAR: $($Item.Name) was deleted at $DeletedDate (Location: Recycle Bin)"
                    [void]$DeletedJars.Add($Result)
                    $DeletedJarsFound = $true
                    Write-Host "! Recently deleted .jar: $($Item.Name)" -ForegroundColor Red
                }
            }
        }
    } catch {
        Write-Host "Recycle Bin access limited: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Check Windows Event Logs for file deletions
    Write-Host "Checking system logs for file deletions..." -ForegroundColor Yellow
    try {
        $Events = Get-WinEvent -FilterHashtable @{
            LogName='Security'
            ID=4663
            StartTime=$OneHourAgo
        } -ErrorAction SilentlyContinue | Where-Object {
            $_.Message -match '\.jar' -and $_.Message -match 'Delete'
        }
        
        foreach ($Event in $Events) {
            $Result = "DELETED_JAR_LOG: File deletion detected in logs at $($Event.TimeCreated)"
            [void]$DeletedJars.Add($Result)
            $DeletedJarsFound = $true
            Write-Host "! Jar deletion in logs: $($Event.TimeCreated)" -ForegroundColor Red
        }
    } catch {
        Write-Host "Event log access limited: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Check recent file history
    Write-Host "Checking recent files..." -ForegroundColor Yellow
    $RecentPaths = @(
        "$env:USERPROFILE\Recent",
        "$env:APPDATA\Microsoft\Windows\Recent"
    )
    
    foreach ($RecentPath in $RecentPaths) {
        if (Test-Path $RecentPath) {
            try {
                $RecentFiles = Get-ChildItem $RecentPath -ErrorAction SilentlyContinue | Where-Object {
                    $_.Name -match '\.jar' -and $_.LastWriteTime -gt $OneHourAgo
                }
                
                foreach ($File in $RecentFiles) {
                    $Result = "RECENT_JAR_ACCESS: $($File.Name) was accessed at $($File.LastWriteTime)"
                    [void]$DeletedJars.Add($Result)
                    Write-Host "! Recent jar access: $($File.Name)" -ForegroundColor Yellow
                }
            } catch {
                # Skip inaccessible paths
            }
        }
    }
    
    return $DeletedJars
}

# Scan Minecraft directories for active cheats
Write-Host "`nScanning Minecraft directories for active cheats..." -ForegroundColor Green
foreach ($Path in $MinecraftPaths) {
    if (Test-Path $Path) {
        Write-Host "Checking: $Path"
        try {
            $Items = Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Extension -match '\.(jar|exe|zip|rar|7z|txt|json|config)$'
            }
            
            foreach ($Item in $Items) {
                $FileName = $Item.Name.ToLower()
                $FullPath = $Item.FullName
                
                # Check for cheat patterns in filename
                foreach ($Pattern in $CheatPatterns) {
                    if ($FileName -match $Pattern) {
                        $Result = "SUSPICIOUS_FILE: $FullPath (Pattern: $Pattern)"
                        [void]$ScanResults.Add($Result)
                        $CheatDetected = $true
                        Write-Host "! Detected: $($Item.Name)" -ForegroundColor Red
                        break
                    }
                }
                
                # Check file content for suspicious strings
                try {
                    if ($Item.Length -lt 5MB) { # Avoid large files
                        $Content = Get-Content $FullPath -Raw -ErrorAction SilentlyContinue
                        if ($Content) {
                            foreach ($Keyword in $SuspiciousKeywords) {
                                if ($Content -match $Keyword) {
                                    $Result = "SUSPICIOUS_CONTENT: $FullPath (Keyword: $Keyword)"
                                    [void]$ScanResults.Add($Result)
                                    $CheatDetected = $true
                                    Write-Host "! Suspicious content: $($Item.Name)" -ForegroundColor Red
                                    break
                                }
                            }
                        }
                    }
                } catch {
                    # Skip files that can't be read
                }
            }
        } catch {
            Write-Host "Error scanning path: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Scan running processes
Write-Host "`nScanning running processes..." -ForegroundColor Green
$Processes = Get-Process | Where-Object { 
    $_.ProcessName -match ($CheatPatterns -join '|') -or
    $_.ProcessName -match ($SuspiciousKeywords -join '|')
}

foreach ($Proc in $Processes) {
    $Result = "SUSPICIOUS_PROCESS: $($Proc.ProcessName) (PID: $($Proc.Id))"
    [void]$ScanResults.Add($Result)
    $CheatDetected = $true
    Write-Host "! Suspicious process: $($Proc.ProcessName)" -ForegroundColor Red
}

# Search for deleted .jar files
$DeletedJarResults = Search-DeletedJarFiles
if ($DeletedJarsFound) {
    $ScanResults.AddRange($DeletedJarResults)
}

# Generate comprehensive report
Write-Host "`n" + "="*70 -ForegroundColor Cyan
if ($CheatDetected -or $DeletedJarsFound) {
    Write-Host "!!! SECURITY ALERT - SUSPICIOUS ACTIVITY DETECTED !!!" -ForegroundColor Red -BackgroundColor White
    
    if ($CheatDetected) {
        Write-Host "Active Cheats Found: $($ScanResults.Where({$_ -match 'SUSPICIOUS'}).Count)" -ForegroundColor Red
    }
    
    if ($DeletedJarsFound) {
        Write-Host "Deleted .jar Files: $($DeletedJarResults.Count)" -ForegroundColor Red
    }
    
    # Save detailed report
    $Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $ReportFile = "crystal_pvp_scan_$Timestamp.txt"
    
    $ReportHeader = @"
Crystal PVP Cheat Scan with .jar Analysis
Generated: $(Get-Date)
Scan Results: $($ScanResults.Count) detections

ACTIVE CHEAT DETECTIONS:
"@
    
    $ReportHeader | Out-File $ReportFile
    $ScanResults | Where-Object { $_ -match "SUSPICIOUS" } | Out-File $ReportFile -Append
    
    if ($DeletedJarsFound) {
        "`nRECENTLY DELETED .JAR FILES (Last Hour):" | Out-File $ReportFile -Append
        $DeletedJarResults | Out-File $ReportFile -Append
    }
    
    Write-Host "Detailed report saved: $ReportFile" -ForegroundColor Yellow
    
    # Return results for Discord bot
    return @{
        CheatsFound = $CheatDetected
        DeletedJarsFound = $DeletedJarsFound
        Results = $ScanResults
        DeletedJarResults = $DeletedJarResults
        Timestamp = $Timestamp
        FilePath = $ReportFile
        DetectionCount = $ScanResults.Count
        DeletedCount = $DeletedJarResults.Count
    }
} else {
    Write-Host "✓ No Crystal PVP cheats or suspicious .jar activity detected" -ForegroundColor Green
    return @{
        CheatsFound = $false
        DeletedJarsFound = $false
        Results = @()
        DeletedJarResults = @()
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        DetectionCount = 0
        DeletedCount = 0
    }
}
