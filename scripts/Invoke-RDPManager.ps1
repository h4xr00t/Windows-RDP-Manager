#Requires -Version 5.1
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPlainTextForPassword',
    'Password',
    Justification = 'Password comes from CLI or config and is converted to SecureString immediately.')]
param(
    [string]$Username         = $env:RDP_USERNAME,
    [string]$Password         = $env:RDP_PASSWORD,
    [string]$TailscaleAuthKey = $env:TAILSCALE_AUTH_KEY,
    [string]$Author           = $env:RDP_AUTHOR,
    [ValidateRange(1, 1440)]
    [int]$DurationMinutes     = 350,
    [switch]$SkipCleanup,
    [switch]$SkipOptimize,
    [switch]$SkipRDP,
    [switch]$SkipUser,
    [switch]$SkipTailscale,
    [switch]$GrantAdmin,
    [string]$ConfigPath       = "$env:ProgramData\RDPManager\config.xml"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'Common.ps1')

function Register-SessionTimerTask {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$UserName,
        [Parameter(Mandatory)][int]$Duration,
        [Parameter(Mandatory)][string]$AuthorName
    )

    $taskName    = 'RDPManager-SessionTimer'
    $timerScript = Join-Path -Path $PSScriptRoot -ChildPath 'Manage-Session.ps1'
    $argument    = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$timerScript`" " +
                   "-DurationMinutes $Duration -Author `"$AuthorName`""

    $action    = New-ScheduledTaskAction    -Execute 'powershell.exe' -Argument $argument
    $trigger   = New-ScheduledTaskTrigger   -AtLogOn -User $UserName
    $principal = New-ScheduledTaskPrincipal -UserId $UserName -LogonType Interactive -RunLevel Limited
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    if (-not $PSCmdlet.ShouldProcess($taskName, 'Register scheduled task')) { return }

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null

    Write-Log "Scheduled task '$taskName' registered for $UserName at logon." SUCCESS
}

Assert-IsAdmin
Start-Log -Name 'main'

$savedConfig = Get-RDPManagerConfig -Path $ConfigPath
if ($savedConfig) {
    Write-Log "Loaded configuration: $ConfigPath"
    if (-not $Username)         { $Username = $savedConfig.Username }
    if (-not $Password -and $savedConfig.PasswordSecure) {
        $Password = ConvertTo-PlainText -SecureString $savedConfig.PasswordSecure
    }
    if (-not $TailscaleAuthKey -and $savedConfig.TailscaleKeySecure) {
        $TailscaleAuthKey = ConvertTo-PlainText -SecureString $savedConfig.TailscaleKeySecure
    }
    if (-not $Author -and $savedConfig.Author) { $Author = $savedConfig.Author }
    if (-not $PSBoundParameters.ContainsKey('DurationMinutes') -and $savedConfig.DurationMinutes) {
        $DurationMinutes = [int]$savedConfig.DurationMinutes
    }
    if (-not $GrantAdmin        -and $savedConfig.GrantAdmin)   { $GrantAdmin   = $true }
    if (-not $SkipCleanup       -and $savedConfig.SkipCleanup)  { $SkipCleanup  = $true }
    if (-not $SkipOptimize      -and $savedConfig.SkipOptimize) { $SkipOptimize = $true }
} else {
    Write-Log "No configuration file found at $ConfigPath" WARN
}

if (-not $Author) { $Author = 'REPLACE_WITH_AUTHOR_NAME' }
if ($Author -eq 'REPLACE_WITH_AUTHOR_NAME') {
    Write-Log 'Author is still the placeholder. Set -Author or run Initialize-Config.ps1.' WARN
}

if (-not $SkipUser) {
    Write-Log '=== User setup ==='
    $userParams = @{ Username = $Username }
    if ($Password)   { $userParams.Password   = $Password }
    if ($GrantAdmin) { $userParams.GrantAdmin = $true }
    & (Join-Path -Path $PSScriptRoot -ChildPath 'Setup-User.ps1') @userParams
}

if (-not $SkipRDP) {
    Write-Log '=== RDP setup ==='
    & (Join-Path -Path $PSScriptRoot -ChildPath 'Setup-RDP.ps1')
}

if (-not $SkipTailscale) {
    Write-Log '=== Tailscale setup ==='
    $tsParams = @{}
    if ($TailscaleAuthKey) { $tsParams.AuthKey = $TailscaleAuthKey }
    & (Join-Path -Path $PSScriptRoot -ChildPath 'Setup-Tailscale.ps1') @tsParams
}

if (-not $SkipCleanup) {
    Write-Log '=== Cleanup ==='
    & (Join-Path -Path $PSScriptRoot -ChildPath 'Cleanup-System.ps1')
}

if (-not $SkipOptimize) {
    Write-Log '=== Optimize ==='
    & (Join-Path -Path $PSScriptRoot -ChildPath 'Optimize-Performance.ps1')
}

Write-Log '=== Workspace init ==='
& (Join-Path -Path $PSScriptRoot -ChildPath 'Manage-Workspace.ps1') -Action Initialize -Username $Username

if ($Username) {
    $existingUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
    if (-not $existingUser) {
        Write-Log "User '$Username' does not exist; session timer task not registered." WARN
    } elseif ($Author -eq 'REPLACE_WITH_AUTHOR_NAME') {
        Write-Log 'Author is placeholder; session timer task not registered.' WARN
    } else {
        Register-SessionTimerTask -UserName $Username -Duration $DurationMinutes -AuthorName $Author
    }
} else {
    Write-Log 'Username not set; session timer task not registered.' WARN
}

Write-Log 'All steps completed.' SUCCESS
