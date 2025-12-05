# ===== LiveDeletedJarScanner_Clean.ps1 =====
$ErrorActionPreference = "SilentlyContinue"

# Configuration
$Webhook = "https://discord.com/api/webhooks/1446644357904994315/cXurGC-8skL34cqX5VRbFjx1Sgu7IfXVjY5wRGnbvV31j-6Nwb6mI0nmzuvAqAbVWDtZ"
$RecoveryFolder = "$env:USERPROFILE\RecoveredJARs"
if (-not (Test-Path $RecoveryFolder)) { New-Item -ItemType Directory -Path $RecoveryFolder | Out-Null }

$Colors = @{
    Cyan   = "Cyan"
    Yellow = "Yellow"
    Green  = "Green"
    Red    = "Red"
}

# Header
Clear-Host
Write-Host "`n=== Complete Deleted JAR Scanner ===`n" -ForegroundColor Cyan
Write-Host "Scanning Recycle Bin and all drives for .jar files..." -ForegroundColor Green
Write-Host ""

# Function to send Discord (silent)
function Send-DiscordAlert {
    param([string]$FileName, [string]$OriginalPath, [string]$Recoverable)
    if (-not $Webhook) { return }
    $payload = @{
        username = "Live Deleted JAR Scanner"
        embeds   = @(
            @{
                title       = "Deleted JAR Detected"
                description = "**File:** $FileName`n**Original Path:** $OriginalPath`n**Recoverable:** $Recoverable"
                color       = 16711680
                timestamp   = (Get-Date).ToString("o")
            }
        )
    } | ConvertTo-Json -Depth 5
    try { Invoke-RestMethod -Uri $Webhook -Method Post -ContentType 'application/json' -Body $payload } catch {}
}

# Scan Recycle Bin
Write-Host "`nScanning Recycle Bin for recoverable .jar files..." -ForegroundColor Cyan
$shell = New-Object -ComObject Shell.Application
$recycleBin = $shell.Namespace(0xA)
$items = $recycleBin.Items()
$found = $false
$spinner = @("|","/","-","\")
$counter = 0

for ($i=0; $i -lt $items.Count; $i++) {
    $item = $items.Item($i)
    $fileName = $item.Name
    $originalPath = $recycleBin.GetDetailsOf($item,1)
    if ($fileName -like "*.jar") {
        $found = $true
        $counter++
        $spin = $spinner[$counter % $spinner.Length]
        Write-Host "`r[$spin] $fileName at $originalPath" -ForegroundColor Yellow -NoNewline
        $targetPath = Join-Path $RecoveryFolder $fileName
        try { Copy-Item $item.Path $targetPath -Force } catch {}
        Send-DiscordAlert -FileName $fileName -OriginalPath $originalPath -Recoverable "Yes (copied to $RecoveryFolder)"
    }
}
Write-Host "`r$(' ' * 80)`r" -NoNewline
if (-not $found) { Write-Host "No recoverable .jar files found in Recycle Bin." -ForegroundColor Green }

# Scan $Recycle.Bin on drives
Write-Host "`nScanning .Bin folders on all drives for .jar files..." -ForegroundColor Cyan
$drives = Get-PSDrive -PSProvider FileSystem
foreach ($drive in $drives) {
    $recyclePath = Join-Path $drive.Root '$Recycle.Bin'
    if (Test-Path $recyclePath) {
        $files = Get-ChildItem -Path $recyclePath -Recurse -Include *.jar -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            Send-DiscordAlert -FileName $file.Name -OriginalPath $file.FullName -Recoverable "Possibly (manual restore)"
        }
    }
}

Write-Host "`nDeleted JAR auto-recovery report completed!" -ForegroundColor Green
Write-Host "Recovered files (if any) are in: $RecoveryFolder" -ForegroundColor Green

# Keep window open until user presses Enter
Write-Host ""
Read-Host "Press Enter to exit..."
