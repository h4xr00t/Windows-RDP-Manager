#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$AuthKey = $env:TAILSCALE_AUTH_KEY,
    [switch]$ForceReinstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Common.ps1"

$TailscaleExe  = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
$InstallerUrl  = 'https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe'

function Install-Tailscale {
    [CmdletBinding()]
    param([switch]$ForceReinstall)
    if ((Test-Path -LiteralPath $TailscaleExe) -and -not $ForceReinstall) {
        Write-Log 'Tailscale is already installed.' INFO
        return
    }

    $tmp = Join-Path $env:TEMP 'tailscale-setup.exe'
    Write-Log "Downloading Tailscale installer..."
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $tmp -UseBasicParsing
    if (-not (Test-Path -LiteralPath $tmp)) { throw 'Failed to download Tailscale installer.' }

    Write-Log 'Running Tailscale installer silently...'
    $p = Start-Process -FilePath $tmp -ArgumentList '/quiet','TS_NOLAUNCH=true' -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "Tailscale installer exited with code $($p.ExitCode)." }

    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path -LiteralPath $TailscaleExe)) {
        throw 'Tailscale executable not found after installation.'
    }
    Write-Log 'Tailscale installed.' SUCCESS
}

function Connect-Tailscale {
    param([string]$Key)
    if (-not $Key) {
        $Key = Read-PlainPassword -Prompt 'Enter Tailscale auth key (tskey-auth-...)'
    }
    if ([string]::IsNullOrWhiteSpace($Key) -or $Key -like 'REPLACE_WITH*') {
        throw 'Tailscale auth key is not configured.'
    }

    Write-Log 'Connecting Tailscale with auth key (key not logged).'
    $output = & $TailscaleExe up --authkey=$Key --unattended --reset 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Tailscale up failed: $output" ERROR
        throw 'Tailscale authentication failed.'
    }
    Write-Log 'Tailscale connected in unattended mode.' SUCCESS
}

function Get-TailscaleIPv4 {
    $ip = & $TailscaleExe ip -4 2>$null
    if ([string]::IsNullOrWhiteSpace($ip)) {
        Write-Log 'Could not retrieve Tailscale IPv4.' ERROR
        return $null
    }
    Write-Log "Tailscale IPv4: $ip" SUCCESS
    return $ip.Trim()
}

function Test-TailscaleConnectivity {
    $status = & $TailscaleExe status --json 2>$null | ConvertFrom-Json
    if ($status.BackendState -eq 'Running') {
        Write-Log 'Tailscale backend is Running.' SUCCESS
        return $true
    }
    Write-Log "Tailscale backend state: $($status.BackendState)" WARN
    return $false
}

Assert-IsAdmin
Start-Log -Name 'setup-tailscale'

Install-Tailscale -ForceReinstall:$ForceReinstall
Connect-Tailscale -Key $AuthKey
if (-not (Test-TailscaleConnectivity)) { throw 'Tailscale connectivity check failed.' }

$ip = Get-TailscaleIPv4
if (-not $ip) { throw 'No Tailscale IPv4 address available.' }

Write-Host "`nUse this Tailscale IP for RDP: $ip`n" -ForegroundColor Green
Write-Log 'Tailscale setup completed.'