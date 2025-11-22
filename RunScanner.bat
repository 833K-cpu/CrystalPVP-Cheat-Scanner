@echo off
chcp 65001 >nul
title Minecraft Cheat Scanner
cls

echo ========================================
echo    Minecraft Cheat Scanner
echo ========================================
echo.
echo This scanner will automatically detect your running Minecraft instance
echo (MultiMC, Modrinth, Lunar, or normal launcher) and scan its mods folder.
echo It only detects known PVP cheat clients.
echo.
echo Press any key to start the scan...
pause >nul

echo.
echo Downloading and starting scanner...
echo.

powershell -ExecutionPolicy Bypass -Command "& {
    Invoke-RestMethod 'https://raw.githubusercontent.com/833K-cpu/CrystalPVP-Cheat-Scanner/main/CrystalPVPJarScanner.ps1' | Invoke-Expression
}"

echo.
echo ========================================
echo Scan completed!
pause
