@echo off
chcp 65001 >nul
title Minecraft Cheat Scanner
cls

echo ========================================
echo    Minecraft Cheat Scanner
echo ========================================
echo.
echo This scanner will:
echo - Automatically detect your running Minecraft mods folder
echo - Scan for known PVP cheat clients
echo - Ignore normal mods to prevent false positives
echo.
echo Examples of Minecraft paths:
echo - Default: C:\Users\YourName\AppData\Roaming\.minecraft
echo - MultiMC: C:\Users\YourName\Desktop\MultiMC\instances\...
echo - Lunar Client: C:\Users\YourName\.lunarclient\offline\...
echo - Badlion: C:\Users\YourName\AppData\Roaming\.badlionclient\.minecraft
echo.
echo Press any key to start the scan...
pause >nul

echo.
echo Downloading and starting CrystalPVPJarScanner...
echo.

powershell -ExecutionPolicy Bypass -NoProfile -Command ^
"try { Invoke-RestMethod 'https://raw.githubusercontent.com/833K-CPU/CrystalPVP-Cheat-Scanner/main/CrystalPVPJarScanner.ps1' | Invoke-Expression } catch { Write-Host '❌ Failed to download or run the scanner!' -ForegroundColor Red; pause }"

echo.
echo ========================================
echo Scan completed!
pause
