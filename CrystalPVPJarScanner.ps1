# ===== LiveDeletedJarScanner_Cosmetic_Final.ps1 =====

$ErrorActionPreference = "SilentlyContinue"

# --------------------------
# Configuration
# --------------------------
$Webhook = "https://discord.com/api/webhooks/1446644357904994315/cXurGC-8skL34cqX5VRbFjx1Sgu7IfXVjY5wRGnbvV31j-6Nwb6mI0nmzuvAqAbVWDtZ"
$RecoveryFolder = "$env:USERPROFILE\RecoveredJARs"
if (-not (Test-Path $RecoveryFolder)) { New-Item -ItemType Directory -Path $RecoveryFolder | Out-Null }

$Colors = @{
    Cyan   = "Cyan"
    Yellow = "Yellow"
    Green  = "Green"
    Red    = "Red"
}

# --------------------------
# Header
# --------------------------
Clear-Host
Write-Host "833K´s Live Deleted JAR Scanner" -ForegroundColor Yellow
Write-Host "Made by 833K" -ForegroundColor White
Write-Host ""

# --------------------------
# Function: Send Discord Alert (silent)
# --------------------------
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

# --------------------------
# Function: Scan Recycle Bin
# --------------------------
function Scan-RecycleBinJARs {
    Write-Host "`n{ Recoverable .jar files in Recycle Bin }" -ForegroundColor $Colors.Cyan

    $shell = New-Object -ComObject Shell.Application
    $recycleBin = $shell.Namespace(0xA)
    $items = $recycleBin.Items()

    $found = $false
    $counter = 0
    $spinner = @("|","/","-","\")

    for ($i=0; $i -lt $items.Count; $i++) {
        $item = $items.Item($i)
        $fileName = $item.Name
        $originalPath = $recycleBin.GetDetailsOf($item, 1)

        if ($fileName -like "*.jar") {
            $found = $true
            $counter++
            $spin = $spinner[$counter % $spinner.Length]
            Write-Host "`r[$spin] $fileName at $originalPath" -ForegroundColor Yellow -NoNewline

            # Copy to recovery folder
            $targetPath = Join-Path $RecoveryFolder $fileName
            try { Copy-Item $item.Path $targetPath -Force } catch {}

            # Discord WebHook
            Send-DiscordAlert -FileName $fileName -OriginalPath $originalPath -Recoverable "Yes (copied to $RecoveryFolder)"
        }
    }

    Write-Host "`r$(' ' * 80)`r" -NoNewline
    if (-not $found) { Write-Host "✅ No recoverable .jar files found in Recycle Bin." -ForegroundColor Green }
}

# --------------------------
# Function: Scan $Recycle.Bin folders (manual)
# --------------------------
function Scan-DrivesRecycleBinManual {
    Write-Host "`n{ .jar files in $Recycle.Bin folders (manual restore) }" -ForegroundColor $Colors.Cyan
    $drives = Get-PSDrive -PSProvider FileSystem

    $counter = 0
    $spinner = @("|","/","-","\")

    foreach ($drive in $drives) {
        $recyclePath = Join-Path $drive.Root '$Recycle.Bin'
        if (Test-Path $recyclePath) {
            try {
                $files = Get-ChildItem -Path $recyclePath -Recurse -Include *.jar -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    $counter++
                    $spin = $spinner[$counter % $spinner.Length]
                    Write-Host "`r[$spin] $($file.Name) at $($file.FullName)" -ForegroundColor Red -NoNewline

                    # Discord WebHook
                    Send-DiscordAlert -FileName $file.Name -OriginalPath $file.FullName -Recoverable "Possibly (manual restore)"
                    
                    Write-Host "`r$($file.Name) at $($file.FullName)" -ForegroundColor Red
                    Write-Host "  Manual restore: Copy-Item '$($file.FullName)' '$RecoveryFolder\'" -ForegroundColor Yellow
                }
            } catch {}
        }
    }
    Write-Host "`r$(' ' * 80)`r" -NoNewline
}

# --------------------------
# Run Scans
# --------------------------
Scan-RecycleBinJARs
Scan-DrivesRecycleBinManual

Write-Host "`nScan complete! Recovered files (if any) are in: $RecoveryFolder" -ForegroundColor Green
