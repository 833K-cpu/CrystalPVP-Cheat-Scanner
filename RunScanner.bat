@echo off
:: =========================================
:: CrystalPVP Jar Scanner Launcher
:: =========================================
chcp 65001 >nul
title CrystalPVP Jar Scanner
cls

echo =========================================
echo      CrystalPVP Jar Scanner
echo =========================================
echo.
echo This launcher will:
echo - Download the latest scanner from GitHub
echo - Automatically run it with PowerShell
echo.
echo Press any key to start the scan...
pause >nul
echo.

:: --- Download and execute the latest scanner ---
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"& {Invoke-RestMethod 'https://raw.githubusercontent.com/833K-cpu/CrystalPVP-Cheat-Scanner/main/CrystalPVPJarScanner.ps1' | Invoke-Expression}"

echo.
echo =========================================
echo Scan completed!
pause
