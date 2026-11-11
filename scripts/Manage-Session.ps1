#Requires -Version 5.1
[CmdletBinding()]
param(
    [int]$DurationMinutes = 350,
    [string]$ProjectName    = 'Windows RDP Manager',
    [string]$ProjectVersion = '1.0.0',
    [string]$Author         = 'h4xr00t'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Popup {
    param([string]$Title, [string]$Message)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        $Message, $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Format-Remaining {
    param([TimeSpan]$Span)
    return ('{0:00}:{1:00}:{2:00}' -f [int]$Span.TotalHours, $Span.Minutes, $Span.Seconds)
}

function Set-PerformanceVisualEffects {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name 'VisualFXSetting' -Value 2 -Type DWord
}

$start = Get-Date
$end   = $start.AddMinutes($DurationMinutes)
$total = New-TimeSpan -Minutes $DurationMinutes

Set-PerformanceVisualEffects

$initial = @"
$ProjectName

Created by: $Author
Project Version: $ProjectVersion

Session started: $($start.ToString('yyyy-MM-dd HH:mm:ss'))
Session duration: $([int]$total.TotalHours) hours and $($total.Minutes) minutes
Expected end:    $($end.ToString('yyyy-MM-dd HH:mm:ss'))

Remaining Time: $(Format-Remaining $total)

Files saved in C:\RDP-Workspace are on persistent disk and can be restored.
Unsaved work may be lost when the session ends.
"@
Show-Popup -Title $ProjectName -Message $initial

$nextHourly = 60
$alerted    = @{}

while ($true) {
    $now       = Get-Date
    $elapsed   = $now - $start
    $remaining = $end - $now

    if ($remaining.TotalSeconds -le 0) { break }

    if ($elapsed.TotalMinutes -ge $nextHourly) {
        $msg = @"
$ProjectName

Created by: $Author

Remaining Time: $(Format-Remaining $remaining)

Session Duration: $(Format-Remaining $total)

Project: $ProjectName
"@
        Show-Popup -Title 'Windows RDP Session' -Message $msg
        $nextHourly += 60
    }

    foreach ($s in @(30,15,5)) {
        $k = "${s}m"
        if (-not $alerted[$k] -and $remaining.TotalMinutes -le $s) {
            $alerted[$k] = $true
            $msg = @"
$ProjectName

Created by: $Author

Remaining Time: $(Format-Remaining $remaining)

Session Duration: $(Format-Remaining $total)

Project: $ProjectName
"@
            Show-Popup -Title 'Windows RDP Session' -Message $msg
        }
    }

    $sleep = [Math]::Min(30, [Math]::Max(1, [int]$remaining.TotalSeconds))
    Start-Sleep -Seconds $sleep
}

$final = @"
$ProjectName

SESSION TIME HAS ENDED.

Created by: $Author
Project: $ProjectName

The session will be terminated in 60 seconds.
Please save your work now.

Files in C:\RDP-Workspace are preserved on disk.
"@
Show-Popup -Title 'Session Ending' -Message $final
Start-Sleep -Seconds 60

$sessionId = (Get-Process -Id $PID).SessionId
logoff.exe $sessionId