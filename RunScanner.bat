@echo off
chcp 65001 >nul
title Minecraft Cheat Scanner
cls

echo ========================================
echo    Minecraft Cheat Scanner
echo ========================================
echo.
echo This scanner will:
echo - Scan the currently running Minecraft instance only
echo - Detect known PVP cheat clients
echo - Zero false positives for normal mods
echo.
echo Make sure Minecraft/Modrinth/MultiMC/Lunar is running
echo before starting the scan.
echo.
echo Press any key to start the scan...
pause >nul

echo.
echo Downloading and starting scanner...
echo.

powershell -ExecutionPolicy Bypass -Command "& {Invoke-RestMethod 'https://raw.githubusercontent.com/833K-cpu/CrystalPVP-Cheat-Scanner/main/CrystalPVPJarScanner.ps1' | Invoke-Expression}"

echo.
echo ========================================
echo Scan completed!
pause
