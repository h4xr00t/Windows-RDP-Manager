# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

Do not open a public Issue for a security vulnerability. Report it privately through GitHub Security Advisories:

https://github.com/h4xr00t/Windows-RDP-Manager/security/advisories/new

> The advisory page becomes available after the repository is public and private vulnerability reporting is enabled in **Settings → Code security and analysis → Private vulnerability reporting**.

Please include:

- Vulnerability description.
- Reproduction steps.
- Affected version.
- Any Proof-of-Concept as an attached file, not in the message body.

A response is provided within 72 hours. Critical vulnerabilities are fixed in the next release.

## Security Design

This project handles RDP, passwords, and Tailscale auth keys. It follows the principles below.

### 1. Secrets Management

- Passwords and Tailscale auth keys are **never stored in code** or in the GitHub repository.
- They are read from:
  - Environment variables (`$env:RDP_PASSWORD`, `$env:TAILSCALE_AUTH_KEY`).
  - Secure prompt via `Read-Host -AsSecureString`.
  - Or the encrypted configuration file (see below).
- In CI (GitHub Actions), no secrets are exposed; real secrets are managed only on the target machine.

### 2. Configuration File

- Location: `C:\ProgramData\RDPManager\config.xml`.
- ACL: **Administrators + SYSTEM only** (inheritance disabled).
- Password and Tailscale auth key are stored as `SecureString`, encrypted with **DPAPI** (tied to the current Windows user and the current machine).
- The file cannot be decrypted from another machine or another account.
- File contents are never written to logs.
- If the file is compromised, delete it immediately:

  ```powershell
  .\scripts\Initialize-Config.ps1 -Remove
  ```

### 3. Password Handling

- Passwords are never logged.
- They are converted to `SecureString` before being passed to Windows commands.
- They are never written to temporary files or unencrypted backups.

### 4. Remote Desktop

- **NLA always enabled** (`UserAuthentication = 1`).
- **RDP encryption level: High** (`MinEncryptionLevel = 3`).
- **Port 3389 is never exposed to the public internet**.
- Windows Firewall allows port 3389 only from `100.64.0.0/10` (Tailscale range).
- Built-in RDP firewall rules are disabled to prevent accidental exposure.

### 5. User Privileges

- The created user is added to `Remote Desktop Users` only.
- **Administrator role is not granted** unless `-GrantAdmin` is passed explicitly, or the option is enabled in the configuration wizard.

### 6. Windows Defender & Updates

- Windows Defender is **not** disabled by this project.
- Windows Update is **not** permanently disabled; it may be paused temporarily through official Windows settings only.
- Essential services (`TermService`, `WinDefend`, `MpsSvc`, `Dnscache`, `Tailscale`) are never modified.

### 7. Session Termination

- Ending a session calls `logoff` for the **current session only**.
- **The host machine is not shut down**.
- **Files in `C:\RDP-Workspace` are not deleted**.

### 8. Logs

- Stored in `C:\ProgramData\RDPManager\Logs`.
- May contain usernames and service names, but **never passwords or Tailscale auth keys**.
- Review logs and remove sensitive details before sharing them for support.

## Best Practices for Operators

- Run the scripts from an elevated PowerShell session on a machine you own or are authorized to administer.
- Use a **Reusable** Tailscale Auth Key with **Ephemeral** or **Pre-authorized** attributes, and rotate it after setup.
- Enable **Tailscale ACLs** to restrict access to port 3389 to specific devices only.
- Verify firewall rules after setup:

  ```powershell
  Get-NetFirewallRule -DisplayName 'RDP-Tailscale-Only' | Format-List
  ```

- Remove the scheduled task when no longer needed:

  ```powershell
  Unregister-ScheduledTask -TaskName 'RDPManager-SessionTimer' -Confirm:$false
  ```
