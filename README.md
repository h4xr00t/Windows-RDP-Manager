# Windows RDP Manager

A PowerShell-based tool for configuring and managing secure Windows Remote Desktop (RDP) environments on Windows 11 Pro and Windows Server 2022.

Features include Tailscale integration, secure user management, system cleanup, performance optimization, temporary session management, and persistent workspace backups.

[![CI](https://github.com/h4xr00t/Windows-RDP-Manager/actions/workflows/main.yml/badge.svg)](https://github.com/h4xr00t/Windows-RDP-Manager/actions/workflows/main.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Pester](https://img.shields.io/badge/Pester-12%20tests-brightgreen)](#testing)

## Quick Start

```powershell
git clone https://github.com/h4xr00t/Windows-RDP-Manager.git
cd Windows-RDP-Manager
.\scripts\Initialize-Config.ps1   # Interactive configuration wizard
.\scripts\Invoke-RDPManager.ps1  # Apply configuration
```

> **⚠️ All scripts must be run from an elevated PowerShell session.**  
> Open PowerShell, then run: `Start-Process PowerShell -Verb RunAs`

Then connect from another authorized Tailscale device:

```powershell
mstsc /v:<TAILSCALE_IP>
```

## Features

### Secure RDP Configuration

- Enable Windows Remote Desktop.
- Keep Network Level Authentication (NLA) enabled.
- Configure high-level RDP encryption.
- Keep Windows Defender Firewall enabled.
- Restrict RDP access to trusted Tailscale devices.
- Verify Remote Desktop service availability.

### User Management

- Create a dedicated RDP account.
- Add the account to the Remote Desktop Users group.
- Keep Administrator privileges disabled by default.
- Securely handle user credentials.

### Tailscale Integration

- Install Tailscale from its official source.
- Authenticate using a securely managed Auth Key.
- Retrieve the device's Tailscale IPv4 address.
- Verify network connectivity.
- Use the private Tailscale network for remote access.

### System Cleanup

Remove selected unnecessary applications when installed:

- Discord
- Telegram
- Unity and Unity Hub
- Epic Games Launcher
- Mozilla Firefox
- Google Chrome
- 7-Zip

Remove obsolete project files and unnecessary temporary files without deleting personal data or essential Windows components.

#### Dry-run preview

The cleanup and workspace scripts support PowerShell's `-WhatIf` switch. Use it to preview what would be removed or modified without actually making changes:

```powershell
.\scripts\Cleanup-System.ps1 -WhatIf
.\scripts\Manage-Workspace.ps1 -Action Backup -WhatIf
```

### Performance Optimization

- Clean temporary files.
- Review startup applications.
- Disable selected unnecessary startup items.
- Review non-essential background services.
- Reduce unnecessary visual effects.
- Optimize power settings.
- Preserve essential Windows, networking, security, and RDP services.

### Session Management

- Configurable session duration.
- Default duration: **350 minutes (5 hours and 50 minutes)**.
- Initial session notification.
- Hourly remaining-time notifications.
- Additional alerts at 30, 15, and 5 minutes.
- Graceful session termination using `logoff`.
- No automatic shutdown of the host machine.

### Persistent Workspace

Default workspace:

`C:\RDP-Workspace`

Includes:

- Project storage.
- Document storage.
- Backup creation.
- Backup restoration.

### Automated Testing

GitHub Actions integration for:

- PowerShell syntax validation.
- PSScriptAnalyzer.
- Pester tests.
- Windows Server 2022 compatibility checks.

## Requirements

| Component | Requirement |
|---|---|
| Operating System | Windows 11 Pro / Windows Server 2022 |
| Architecture | 64-bit |
| PowerShell | 5.1 or later |
| RAM | 8 GB recommended |
| CPU | 2 vCPU recommended |
| Storage | 14 GB or more |
| Permissions | Administrator |
| Networking | Tailscale account |

## Installation

Clone the repository:

```powershell
git clone https://github.com/h4xr00t/Windows-RDP-Manager.git
```

Navigate to the project directory:

```powershell
cd Windows-RDP-Manager
```

## Configuration

Open PowerShell as Administrator and run:

```powershell
.\scripts\Initialize-Config.ps1
```

The configuration wizard guides you through:

| Setting | Description |
|---|---|
| Username | RDP account name |
| Password | RDP account password |
| Tailscale Auth Key | Authentication key |
| Author | Project owner name |
| Duration | Session duration in minutes |
| Administrator | Optional administrator privileges |
| Cleanup | Enable or skip system cleanup |
| Optimization | Enable or skip performance optimization |

### Placeholder Values

The wizard prompts for the following settings. The values below are **placeholders** and must be replaced with real credentials during configuration:

| **Setting** | **Placeholder** |
| :---------- | :----------------------------- |
| Username | `h4xr00t` |
| Password | `RDP4FREE` |
| Author | `h4xr00t` |
| Duration | 350 (default, max 1440) |

Configuration file:

```text
C:\ProgramData\RDPManager\config.xml
```

Sensitive configuration data should be protected using Windows DPAPI and restrictive file permissions.

### Configuration Commands

Initialize or update configuration:

```powershell
.\scripts\Initialize-Config.ps1
```

Display current configuration:

```powershell
.\scripts\Initialize-Config.ps1 -ShowOnly
```

Force reconfiguration:

```powershell
.\scripts\Initialize-Config.ps1 -Force
```

Remove configuration:

```powershell
.\scripts\Initialize-Config.ps1 -Remove
```

## Usage

Start Windows RDP Manager:

```powershell
.\scripts\Invoke-RDPManager.ps1
```

The application loads its configuration automatically.

### Optional Parameters

| Parameter | Description |
|---|---|
| `-Username` | RDP username |
| `-Password` | RDP password |
| `-TailscaleAuthKey` | Tailscale authentication key |
| `-Author` | Project owner |
| `-DurationMinutes` | Session duration (default: 350) |
| `-GrantAdmin` | Grant administrator privileges |
| `-SkipUser` | Skip user creation |
| `-SkipRDP` | Skip RDP configuration |
| `-SkipTailscale` | Skip Tailscale setup |
| `-SkipCleanup` | Skip system cleanup |
| `-SkipOptimize` | Skip performance optimization |
| `-ConfigPath` | Custom configuration path |

Never place real passwords or authentication keys directly in source code, command history, or public repository files.

### Remote Connection

After successful configuration, the application displays the device's Tailscale IPv4 address.

Connect from another authorized device using:

```powershell
mstsc /v:<TAILSCALE_IP>
```

Enter the configured RDP username and password when prompted.

## Session Management

Default session duration: **350 minutes (05:50:00)**

Allowed range: **1 to 1440 minutes** (24 hours maximum).

The session timer provides the following notifications:

| Time | Notification |
|---|---|
| Session start | Session information |
| Every hour | Remaining time |
| 30 minutes remaining | Warning |
| 15 minutes remaining | Warning |
| 5 minutes remaining | Final warning |
| Session end | Termination notification |

Scheduled task:

```text
RDPManager-SessionTimer
```

When the configured duration expires:

1. Display the final notification.
2. Allow a 60-second save period.
3. Log off the current RDP session.
4. Keep the host operating system running.
5. Preserve files stored in the persistent workspace.

To remove the scheduled task:

```powershell
Unregister-ScheduledTask `
    -TaskName "RDPManager-SessionTimer" `
    -Confirm:$false
```

**Note:** Session duration controls the application's session timer. It does not override hosting-provider limits or guarantee that a virtual machine remains available.

## Workspace & Backups

Workspace location:

```text
C:\RDP-Workspace
```

Directory structure:

```text
RDP-Workspace/
├── Projects/
├── Documents/
└── Backups/
```

### Create a Backup

```powershell
.\scripts\Manage-Workspace.ps1 -Action Backup
```

### Restore a Backup

```powershell
.\scripts\Manage-Workspace.ps1 `
    -Action Restore `
    -RestoreFrom "<BACKUP_FILE_PATH>"
```

Files stored on persistent storage can be recovered across sessions, provided the storage itself is retained.

Ending an RDP session does not delete workspace files. However, deleting the virtual machine may remove its operating system and installed applications.

## Testing

Install the required development tools:

```powershell
Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck -MinimumVersion 5.0
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck
```

> `-SkipPublisherCheck` allows installation of a newer module version when its publisher signature differs from that of an already-installed version. Use it only when you trust the configured repository and package source. [Microsoft documentation](https://learn.microsoft.com/en-us/powershell/module/powershellget/install-module).

### Run Pester Tests

```powershell
Invoke-Pester ./tests -Output Detailed
```

### Run PSScriptAnalyzer

```powershell
Invoke-ScriptAnalyzer `
    -Path ./scripts `
    -Recurse `
    -Settings ./PSScriptAnalyzerSettings.psd1
```

### Validate PowerShell Syntax

```powershell
Get-ChildItem ./scripts -Filter *.ps1 -Recurse |
ForEach-Object {
    $tokens = $null
    $errors = $null

    [System.Management.Automation.Language.Parser]::ParseFile(
        $_.FullName,
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null

    if ($errors.Count -gt 0) {
        Write-Error "$($_.Name): $($errors[0].Message)"
    }
    else {
        Write-Host "PASS: $($_.Name)"
    }
}
```

## Troubleshooting

| **Symptom** | **Cause** | **Fix** |
| :------------------------------------ | :--------------------------------- | :--------------------------------------------------------------------- |
| `RDP listener NOT found` | TermService is stopped | `Start-Service TermService` |
| `Tailscale backend state: NeedsLogin` | Auth key expired | Re-run `Initialize-Config.ps1 -Force` |
| `Cannot decrypt config.xml` | Different Windows user or machine | Delete the file and re-run `Initialize-Config.ps1` |
| Pester fails with `BeforeAll` error | Pester 3.4 is loaded instead of 5+ | `Install-Module Pester -Force -SkipPublisherCheck -MinimumVersion 5.0` |
| `Administrator privileges required` | PowerShell not elevated | Reopen PowerShell with "Run as Administrator" |

## Project Structure

```text
Windows-RDP-Manager/
│
├── .github/
│   └── workflows/
│       └── main.yml
│
├── scripts/
│   ├── Common.ps1
│   ├── Initialize-Config.ps1
│   ├── Setup-RDP.ps1
│   ├── Setup-User.ps1
│   ├── Setup-Tailscale.ps1
│   ├── Cleanup-System.ps1
│   ├── Optimize-Performance.ps1
│   ├── Manage-Session.ps1
│   ├── Manage-Workspace.ps1
│   └── Invoke-RDPManager.ps1
│
├── tests/
│   ├── Common.Tests.ps1
│   └── Scripts.Tests.ps1
│
├── PSScriptAnalyzerSettings.psd1
├── README.md
├── SECURITY.md
├── LICENSE
└── .gitignore
```

## Security

Security is a core part of this project.

- Never commit passwords or Tailscale Auth Keys.
- Protect configuration files with appropriate Windows ACLs.
- Use DPAPI for sensitive local configuration data.
- Keep NLA enabled.
- Keep Windows Defender and Windows Firewall enabled.
- Restrict RDP access to authorized Tailscale devices.
- Avoid granting unnecessary Administrator privileges.
- Do not disable essential Windows services.
- Never expose RDP port 3389 directly to the public internet.
- Review logs before sharing them.
- **DPAPI scope:** `config.xml` is encrypted for the current Windows user on the current machine. Running the manager as a different user, or copying the file to another machine, requires re-running `Initialize-Config.ps1`.

For vulnerability reporting and security details, see [SECURITY.md](SECURITY.md).

## Uninstall

Run the following commands from an elevated PowerShell session:

```powershell
# Remove the scheduled session timer
Unregister-ScheduledTask -TaskName 'RDPManager-SessionTimer' -Confirm:$false

# Remove configuration and logs
.\scripts\Initialize-Config.ps1 -Remove
Remove-Item "$env:ProgramData\RDPManager" -Recurse -Force

# Optional: remove the RDP user
Remove-LocalGroupMember -Group 'Remote Desktop Users' -Member "<username>"
Remove-LocalUser -Name "<username>"
```

> Files in `C:\RDP-Workspace` are not removed automatically. Delete them manually if needed.

## Contributing

Contributions, bug reports, and feature requests are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Make your changes.
4. Run the tests.
5. Submit a Pull Request.

Create a branch:

```bash
git checkout -b feature/my-feature
```

Run tests:

```powershell
Invoke-Pester ./tests
```

Please ensure that all relevant tests pass before submitting your Pull Request.

## License

This project is licensed under the MIT License.

See the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <strong>Windows RDP Manager</strong><br>
  Secure. Lightweight. Open Source.
</p>
