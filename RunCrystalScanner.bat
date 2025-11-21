@echo off
echo Crystal PVP Scanner - Direct from GitHub
powershell -ExecutionPolicy Bypass -Command "& {Invoke-RestMethod 'https://raw.githubusercontent.com/833K-cpu/CrystalPVP-Cheat-Scanner/main/CrystalPVPJarScanner.ps1' | Invoke-Expression}"
pause
