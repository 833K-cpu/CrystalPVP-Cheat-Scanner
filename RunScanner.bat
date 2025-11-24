@echo off
chcp 65001 >nul
title CrystalPVP Mod Size Scanner
cls

echo ==============================================
echo        CrystalPVP Mod Size Scanner
echo ==============================================
echo.
echo This scanner will:
echo - Automatically detect your running Minecraft instance
echo - Scan ONLY the mods of the active instance
echo - Compare mod file sizes with official Modrinth files
echo - Detect modified / injected / cheat JARs
echo.
echo Make sure Minecraft is running before starting!
echo.
echo Press any key to begin...
pause >nul

cls
echo ==============================================
echo       Downloading latest scanner script...
echo ==============================================
echo.

powershell -ExecutionPolicy Bypass -Command ^
 "& {Invoke-RestMethod 'https://raw.githubusercontent.com/833K-cpu/CrystalPVP-Cheat-Scanner/main/CrystalPVPJarScanner.ps1' | Invoke-Expression}"

echo.
echo ==============================================
echo Scan complete!
echo ==============================================
pause
