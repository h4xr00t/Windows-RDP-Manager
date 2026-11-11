#Requires -Version 5.1
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'Required to convert wizard-entered plaintext to SecureString for DPAPI encryption in config.xml. The plaintext is never logged or persisted.')]
[CmdletBinding()]
param(
    [string]$ConfigPath = "$env:ProgramData\RDPManager\config.xml",
    [switch]$ShowOnly,
    [switch]$Force,
    [switch]$Remove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'Common.ps1')

function Read-Answer {
    param([string]$Prompt, [string]$Default = '')
    $display = if ($Default) { "$Prompt [$Default]" } else { $Prompt }
    $val = Read-Host -Prompt $display
    if ([string]::IsNullOrWhiteSpace($val)) { return $Default }
    return $val
}

function Read-YesNo {
    param([string]$Prompt, [bool]$Default = $false)
    $def = if ($Default) { 'Y/n' } else { 'y/N' }
    $val = Read-Host -Prompt "$Prompt [$def]"
    if ([string]::IsNullOrWhiteSpace($val)) { return $Default }
    return ($val -match '^(y|yes|o|oui)$')
}

function New-RDPManagerConfig {
    param([string]$Path)

    Write-Host ''
    Write-Host '=== RDP Manager Configuration Wizard ===' -ForegroundColor Cyan
    Write-Host ''

    $existing = Get-RDPManagerConfig -Path $Path

    $defaultUser = if ($existing -and $existing.Username) { $existing.Username } else { $env:USERNAME }
    $username = Read-Answer -Prompt 'RDP username' -Default $defaultUser

    Write-Host 'RDP password (leave empty to keep existing):'
    $plainPwd = Read-PlainPassword -Prompt 'Password'
    if ([string]::IsNullOrEmpty($plainPwd)) {
        if ($existing -and $existing.PasswordSecure) {
            $securePwd = $existing.PasswordSecure
        } else {
            throw 'A password is required for first-time setup.'
        }
    } else {
        $securePwd = ConvertTo-SecureString -String $plainPwd -AsPlainText -Force
    }

    $updateKey = Read-YesNo -Prompt 'Set/update Tailscale auth key?' -Default $false
    if ($updateKey) {
        $plainKey  = Read-PlainPassword -Prompt 'Tailscale auth key (tskey-...)'
        $secureKey = ConvertTo-SecureString -String $plainKey -AsPlainText -Force
    } elseif ($existing -and $existing.TailscaleKeySecure) {
        $secureKey = $existing.TailscaleKeySecure
    } else {
        $secureKey = $null
    }

    $defaultAuthor = if ($existing -and $existing.Author) { $existing.Author } else { '' }
    $author = Read-Answer -Prompt 'Author name' -Default $defaultAuthor

    $defaultDuration = if ($existing -and $existing.DurationMinutes) { $existing.DurationMinutes } else { 350 }
    $durationStr = Read-Answer -Prompt 'Session duration (minutes)' -Default $defaultDuration
    $duration = [int]$durationStr

    $defaultAdmin = if ($existing -and $existing.GrantAdmin) { [bool]$existing.GrantAdmin } else { $false }
    $grantAdmin = Read-YesNo -Prompt 'Grant Administrator role' -Default $defaultAdmin

    $skipCleanup  = Read-YesNo -Prompt 'Skip cleanup step'        -Default $false
    $skipOptimize = Read-YesNo -Prompt 'Skip optimization step'   -Default $false

    $config = [PSCustomObject]@{
        Username           = $username
        PasswordSecure     = $securePwd
        TailscaleKeySecure = $secureKey
        Author             = $author
        DurationMinutes    = $duration
        GrantAdmin         = $grantAdmin
        SkipCleanup        = $skipCleanup
        SkipOptimize       = $skipOptimize
        SavedAt            = (Get-Date)
    }

    Save-RDPManagerConfig -Config $config -Path $Path
    Write-Host ''
    Write-Host "Configuration saved: $Path" -ForegroundColor Green
    Write-Host ''

    return $config
}

function Show-RDPManagerConfig {
    param([string]$Path)

    $config = Get-RDPManagerConfig -Path $Path
    if (-not $config) {
        Write-Host 'No configuration found.' -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Host '=== Current Configuration ===' -ForegroundColor Cyan
    Write-Host "  Username:        $($config.Username)"
    Write-Host "  Author:          $($config.Author)"
    Write-Host "  Duration:        $($config.DurationMinutes) minutes"
    Write-Host "  Grant Admin:     $($config.GrantAdmin)"
    Write-Host "  Skip Cleanup:    $($config.SkipCleanup)"
    Write-Host "  Skip Optimize:   $($config.SkipOptimize)"
    Write-Host "  Password:        $(if ($config.PasswordSecure) { '[set]' } else { '[not set]' })"
    Write-Host "  Tailscale Key:   $(if ($config.TailscaleKeySecure) { '[set]' } else { '[not set]' })"
    Write-Host "  Saved At:        $($config.SavedAt)"
    Write-Host ''
}

if ($Remove) {
    if (Test-Path -LiteralPath $ConfigPath) {
        Remove-Item -LiteralPath $ConfigPath -Force
        Write-Host "Removed: $ConfigPath" -ForegroundColor Yellow
    } else {
        Write-Host "Nothing to remove: $ConfigPath" -ForegroundColor Yellow
    }
    return
}

if ($ShowOnly) {
    Show-RDPManagerConfig -Path $ConfigPath
    return
}

if ($MyInvocation.InvocationName -eq '.') { return }

Start-Log -Name 'config'

$existing = Get-RDPManagerConfig -Path $ConfigPath
if ($existing -and -not $Force) {
    Write-Host 'Existing configuration found.' -ForegroundColor Yellow
    Show-RDPManagerConfig -Path $ConfigPath
    if (-not (Read-YesNo -Prompt 'Update configuration?' -Default $false)) {
        Write-Host 'Configuration unchanged.'
        return
    }
}

$config = New-RDPManagerConfig -Path $ConfigPath

Write-Host 'Configuration is ready. Run:' -ForegroundColor Green
Write-Host '  .\scripts\Invoke-RDPManager.ps1' -ForegroundColor White
Write-Host ''