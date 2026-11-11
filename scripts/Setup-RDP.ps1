#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$TailscaleCidr = '100.64.0.0/10'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'Common.ps1')

function Enable-RemoteDesktop {
    [CmdletBinding()]
    param()

    $tsPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    Set-ItemProperty -Path $tsPath -Name 'fDenyTSConnections'  -Value 0 -Type DWord
    Set-ItemProperty -Path $tsPath -Name 'fSingleSessionPerUser' -Value 0 -Type DWord

    $rdpTcp = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
    Set-ItemProperty -Path $rdpTcp -Name 'UserAuthentication' -Value 1 -Type DWord
    Set-ItemProperty -Path $rdpTcp -Name 'SecurityLayer'      -Value 2 -Type DWord
    Set-ItemProperty -Path $rdpTcp -Name 'MinEncryptionLevel' -Value 3 -Type DWord

    Set-Service -Name TermService -StartupType Automatic
    Start-Service -Name TermService -ErrorAction SilentlyContinue
    Write-Log 'Remote Desktop enabled with NLA and High encryption.' SUCCESS
}

function Set-RdpFirewallRule {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Cidr)

    $ruleName = 'RDP-Tailscale-Only'
    Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule -ErrorAction SilentlyContinue

    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP `
        -LocalPort 3389 -RemoteAddress $Cidr -Action Allow -Profile Any -Enabled True | Out-Null

    Get-NetFirewallRule -Group '@FirewallAPI.dll,-28752' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -notlike '*Tailscale*' } |
        Set-NetFirewallRule -Enabled False -ErrorAction SilentlyContinue

    Write-Log "Firewall restricted RDP to $Cidr." SUCCESS
}

function Test-RdpListener {
    [CmdletBinding()]
    param()

    $tcp = Get-NetTCPConnection -LocalPort 3389 -State Listen -ErrorAction SilentlyContinue
    if ($tcp) {
        Write-Log 'RDP listener is active on port 3389.' SUCCESS
        return $true
    }
    Write-Log 'RDP listener NOT found on port 3389.' ERROR
    return $false
}

Assert-IsAdmin
Start-Log -Name 'setup-rdp'
Write-Log 'Starting RDP configuration...'

Enable-RemoteDesktop
Set-RdpFirewallRule -Cidr $TailscaleCidr

if (-not (Test-RdpListener)) {
    throw 'RDP setup failed: service is not listening.'
}

Write-Log 'RDP setup completed successfully.' SUCCESS