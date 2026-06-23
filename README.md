# âš¡ Manutenzione PRO MAX

All-in-one Windows maintenance and diagnostics tool with a modern dark GUI. Portable, no installation required.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

### Updates
- **Winget Upgrade**: update all installed packages silently
- **Microsoft Store**: refresh Store apps
- **Windows Update**: search and install system updates (COM API, no module dependencies)

### Cleanup
- **Temp files**: clears user temp, system temp, internet cache, crash dumps
- **Disk Cleanup**: automated Windows disk cleanup with all flags enabled

### Network
- **Flush DNS / Renew IP / Reset Winsock**
- **Wi-Fi Passwords**: displays all saved SSID and passwords (multi-language regex)
- **Ping Test**: latency to Google DNS, Cloudflare, OpenDNS
- **Speed Internet**: Cloudflare-based speed test (ping, download 20MB, upload 5MB)

### Repair
- **SFC + DISM**: full system file check and repair
- **Restore Point**: creates a system restore point

### Security
- **Windows Defender Quick Scan**: auto-detects MpCmdRun.exe path
- **Event Log Errors**: last 20 critical/error events (7 days)

### Diagnostics
- **System Info**: OS, CPU, RAM, GPU, BIOS, disks
- **Battery Report**: generates and opens HTML report
- **Uptime**: last boot time with reboot recommendation
- **Top Processes**: top 15 by CPU usage
- **Startup Programs**: WMI + Registry (HKLM/HKCU Run)
- **Disk Space Analysis**: top folders by size
- **Service Status**: 10 critical Windows services
- **CPU Unlock**: unhides all hidden processor power settings (boost, parking, idle)
- **Remote Assist**: downloads and launches RustDesk portable, shows ID/password

### System
- **Run All**: executes full maintenance sequence with one click
- **Export Report**: saves full log to Desktop
- **Elevate Admin**: relaunch as administrator
- **Restart PC**: with confirmation dialog

## Screenshot

> Add a screenshot here after first build

## Requirements

- Windows 10 or 11
- PowerShell 5.1 (pre-installed) or PowerShell 7 (auto-installed if missing)
- Administrator privileges (for most features)
- Winget (for package updates)

## Usage

### Run as script
```powershell
# Right-click > Run with PowerShell (as Admin)
# Or from terminal:
pwsh -ExecutionPolicy Bypass -File Manutenzione_PRO_MAX_v3_FINAL.ps1
```

### Run as portable EXE
Download `ManutenzioneProMax.exe` from [Releases](../../releases). Double-click to run (requests admin).

## Build EXE from source

```powershell
# Download PS2EXE
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://github.com/MScholtes/PS2EXE/archive/refs/heads/master.zip" -OutFile "$env:TEMP\ps2exe.zip"
Expand-Archive "$env:TEMP\ps2exe.zip" -DestinationPath "$env:TEMP\ps2exe" -Force
Import-Module "$env:TEMP\ps2exe\PS2EXE-master\Module\ps2exe.psm1"

# Compile
Invoke-PS2EXE -InputFile "Manutenzione_PRO_MAX_v3_FINAL.ps1" -OutputFile "ManutenzioneProMax.exe" -NoConsole -RequireAdmin -SupportOS -LongPaths -Title "Manutenzione PRO MAX" -Description "Windows maintenance tool" -Company "Peters IT" -Version "3.0.0.0" -Copyright "2026"
```

## Code Signing (optional)

```powershell
# Create self-signed cert (once)
$cert = New-SelfSignedCertificate -Subject "CN=Peters IT" -Type CodeSigningCert -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddYears(5)
Export-Certificate -Cert $cert -FilePath "PetersIT.cer"

# Sign the EXE
Set-AuthenticodeSignature -FilePath "ManutenzioneProMax.exe" -Certificate $cert -TimestampServer "http://timestamp.digicert.com" -HashAlgorithm SHA256

# Trust on local machine (admin)
Import-Certificate -FilePath "PetersIT.cer" -CertStoreLocation Cert:\LocalMachine\TrustedPublisher
Import-Certificate -FilePath "PetersIT.cer" -CertStoreLocation Cert:\LocalMachine\Root
```

## Architecture

- **Single-thread GUI** with buffered logging (no freeze)
- **Async process output** via `ConcurrentQueue` + event handlers
- **UI pump** via `DoEvents()` at controlled intervals
- **PS5/PS7 compatible**: auto-detects `ResponseTime` vs `Latency` for ping
- **Zero external modules**: Windows Update uses COM API directly
- **No popups in EXE mode**: no `Write-Host`, no `Install-Module`

## Auto-update (optional)

The EXE can check for updates from this repo. Add a `version.txt` file with the current version number. The EXE compares at startup and self-updates from the latest Release.

## License

[MIT](LICENSE)

## Author

**Peters IT** - [@pierpaolosanna](https://github.com/pierpaolosanna)