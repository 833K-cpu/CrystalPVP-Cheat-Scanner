@echo off
chcp 65001 >nul
title CrystalPVP Cheat Scanner
cls

echo ========================================
echo     CrystalPVP Cheat Scanner
echo ========================================
echo.
echo This scanner will:
echo - Auto-detect your running Minecraft/Modrinth/MultiMC instance
echo - Scan mods for known PVP cheat clients
echo - Ignore normal mods to avoid false flags
echo.
echo Press any key to start the scan...
pause >nul

echo.
echo Downloading and starting scanner...
echo.

powershell -ExecutionPolicy Bypass -Command ^
"& {Invoke-RestMethod 'https://raw.githubusercontent.com/833K-cpu/CrystalPVP-Cheat-Scanner/main/CrystalPVPJarScanner.ps1' | Invoke-Expression}"

echo.
echo ========================================
echo Scan completed!
pause
