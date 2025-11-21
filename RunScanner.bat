@echo off
chcp 65001 >nul
title Minecraft Cheat Scanner
cls

echo ========================================
echo    Minecraft Cheat Scanner
echo ========================================
echo.
echo This scanner will:
echo - Ask for your Minecraft folder path
echo - Scan for PVP cheat clients
echo - Detect recently deleted .jar files
echo - Check running processes
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
echo Downloading and starting scanner...
echo.

powershell -ExecutionPolicy Bypass -Command "& {Invoke-RestMethod 'https://raw.githubusercontent.com/DEIN_USERNAME/CrystalPVP-Cheat-Scanner/main/CrystalPVPJarScanner.ps1' | Invoke-Expression}"

echo.
echo ========================================
echo Scan completed!
pause
