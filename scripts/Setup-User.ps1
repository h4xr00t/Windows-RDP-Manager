#Requires -Version 5.1
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPlainTextForPassword',
    'Password',
    Justification = 'Password comes from CLI/env and is converted to SecureString immediately; never logged.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'Required to convert env/CLI plaintext to SecureString for New-LocalUser. Value is never logged or persisted.')]
param(
    [string]$Username = $env:RDP_USERNAME,
    [string]$Password = $env:RDP_PASSWORD,
    [switch]$GrantAdmin
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Common.ps1"

function Set-RdpLocalUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][SecureString]$SecurePassword
    )

    $existing = Get-LocalUser -Name $Name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "User '$Name' already exists; updating password." WARN
        Set-LocalUser -Name $Name -Password $SecurePassword -PasswordNeverExpires $true
    } else {
        New-LocalUser -Name $Name -Password $SecurePassword -FullName $Name `
            -Description 'RDP user' -PasswordNeverExpires -AccountNeverExpires | Out-Null
        Write-Log "User '$Name' created." SUCCESS
    }

    $user = Get-LocalUser -Name $Name
    if (-not $user.Enabled) {
        Enable-LocalUser -Name $Name
        Write-Log "User '$Name' enabled." INFO
    }

    $rdpGroup = 'Remote Desktop Users'
    $members  = Get-LocalGroupMember -Group $rdpGroup -ErrorAction SilentlyContinue
    $already  = $members | Where-Object { $_.Name -match "\\$([regex]::Escape($Name))$" }
    if (-not $already) {
        Add-LocalGroupMember -Group $rdpGroup -Member $Name
        Write-Log "User '$Name' added to Remote Desktop Users." SUCCESS
    } else {
        Write-Log "User '$Name' is already a member of Remote Desktop Users." INFO
    }
}

function Set-AdminMembership {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name, [bool]$Enable)

    $group    = 'Administrators'
    $members  = Get-LocalGroupMember -Group $group -ErrorAction SilentlyContinue
    $isMember = $members | Where-Object { $_.Name -match "\\$([regex]::Escape($Name))$" }

    if ($Enable -and -not $isMember) {
        Add-LocalGroupMember -Group $group -Member $Name
        Write-Log "User '$Name' added to Administrators." WARN
    } elseif (-not $Enable -and $isMember) {
        Remove-LocalGroupMember -Group $group -Member $Name
        Write-Log "User '$Name' removed from Administrators." INFO
    }
}

Assert-IsAdmin
Start-Log -Name 'setup-user'

if (-not $Username) {
    $Username = Read-Host -Prompt 'Enter RDP username'
}
if (-not $Password) {
    $Password = Read-PlainPassword -Prompt "Enter password for '$Username'"
}

# U can change the Username and Password here if U want <3
if ([string]::IsNullOrWhiteSpace($Username)) {
    throw 'Username is required. Set $env:RDP_USERNAME or pass -Username.'
}
if ([string]::IsNullOrWhiteSpace($Password)) {
    throw 'Password is required.'
}
if ($Username -like 'REPLACE_WITH*' -or $Password -like 'REPLACE_WITH*') {
    throw 'A placeholder value was provided. Enter real credentials.'
}

$securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force

Set-RdpLocalUser   -Name $Username -SecurePassword $securePassword
Set-AdminMembership -Name $Username -Enable $GrantAdmin.IsPresent

Write-Log "User setup completed for '$Username'." SUCCESS