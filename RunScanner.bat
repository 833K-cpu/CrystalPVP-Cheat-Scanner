@echo off
chcp 65001 >nul
title Minecraft Cheat Scanner
cls

echo ========================================
echo    Minecraft Cheat Scanner
echo ========================================
echo.
echo This scanner will:
echo - Automatically detect running Minecraft instance
echo - Scan its mods folder
echo - Detect PVP cheat clients
echo.
echo Press any key to start the scan...
pause >nul

echo.
echo Downloading and starting scanner...
echo.

powershell -ExecutionPolicy Bypass -Command "& {
    # Detect running Minecraft process and its gameDir
    $runningMC = Get-Process java,javaw,wjava -ErrorAction SilentlyContinue
    $MinecraftPath = $null

    foreach ($p in $runningMC) {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter \"ProcessId=$($p.Id)\").CommandLine
            if ($cmd -match '--gameDir\s+""?([^""]+)""?') {
                $MinecraftPath = $matches[1]
                break
            }
        } catch {}
    }

    if (-not $MinecraftPath) {
        $MinecraftPath = Join-Path $env:APPDATA '.minecraft'
        Write-Host '🟡 Minecraft not running — using default path: ' $MinecraftPath
    } else {
        Write-Host '🟢 Running Minecraft detected — scanning mods in: ' $MinecraftPath
    }

    # Set mods folder
    $ModsPath = Join-Path $MinecraftPath 'mods'

    # Download and run CrystalPVPJarScanner with detected mods path
    Invoke-RestMethod 'https://raw.githubusercontent.com/833K-CPU/CrystalPVP-Cheat-Scanner/main/CrystalPVPJarScanner.ps1' | Invoke-Expression
}"

echo.
echo ========================================
echo Scan completed!
pause
