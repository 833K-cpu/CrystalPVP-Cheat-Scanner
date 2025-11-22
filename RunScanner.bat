@echo off
:: Set UTF-8 encoding
chcp 65001 >nul

:: Set window title
title Minecraft Cheat Scanner

:: Clear screen
cls

:: Display header
echo ========================================
echo       Minecraft Cheat Scanner
echo ========================================
echo.

:: Explain purpose
echo This scanner will:
echo - Ask for your Minecraft folder path (if needed)
echo - Scan for PVP cheat clients
echo - Detect recently deleted .jar files
echo - Check running Minecraft processes
echo.

:: Show example paths
echo Examples of Minecraft paths:
echo - Default: C:\Users\YourName\AppData\Roaming\.minecraft
echo - MultiMC: C:\Users\YourName\Desktop\MultiMC\instances\...
echo - Lunar Client: C:\Users\YourName\.lunarclient\offline\...
echo - Badlion: C:\Users\YourName\AppData\Roaming\.badlionclient\.minecraft
echo.

:: Prompt user to start
echo Press any key to start the scan...
pause >nul

:: Clear screen before running scanner
cls
echo Downloading and starting scanner...
echo.

:: Run the PowerShell scanner from GitHub
powershell -ExecutionPolicy Bypass -Command "& {
    try {
        Invoke-RestMethod 'https://raw.githubusercontent.com/833K-CPU/CrystalPVP-Cheat-Scanner/main/CrystalPVPJarScanner.ps1' | Invoke-Expression
    } catch {
        Write-Host '❌ Failed to download or run the scanner:' $_.Exception.Message -ForegroundColor Red
        pause
    }
}"

echo.
echo ========================================
echo Scan completed!
pause
