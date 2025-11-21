# Crystal PVP Cheat Scanner

Advanced detection system for Minecraft PVP cheat clients with custom path support.

## Features

- 🔍 **Custom Path Support** - Works with any Minecraft client (Vanilla, Lunar, Badlion, MultiMC)
- 🗑️ **Deleted .jar Detection** - Finds .jar files deleted within last hour
- ⚡ **Real-time Monitoring** - Checks running processes
- 📊 **Comprehensive Reporting** - Detailed logs and results

## Supported Clients

- **Vanilla Minecraft** (default .minecraft folder)
- **Lunar Client**
- **Badlion Client** 
- **MultiMC**
- **Any custom Minecraft installation**

## Usage

### One-Click Scan:
```batch
powershell -ExecutionPolicy Bypass -Command "& {Invoke-RestMethod 'https://raw.githubusercontent.com/DEIN_USERNAME/CrystalPVP-Cheat-Scanner/main/CrystalPVPJarScanner.ps1' | Invoke-Expression}"
