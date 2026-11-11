#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Common.ps1"

function Clear-TempFiles {
    foreach ($p in @($env:TEMP,'C:\Windows\Temp')) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue |
            ForEach-Object {
                try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
                catch { Write-Log "Skipped $($_.FullName): $_" WARN }
            }
        Write-Log "Cleaned temp: $p" SUCCESS
    }
}

function Set-PowerPlanHighPerformance {
    $scheme = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    powercfg.exe /setactive $scheme 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Log 'Power plan set to High Performance.' SUCCESS }
    else { Write-Log 'Could not set High Performance power plan.' WARN }
}

function Disable-UnnecessaryStartupItems {
    $runKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
    )
    $pattern = 'Discord|Telegram|Unity|EpicGames|Firefox|Chrome|7-Zip|Update|Helper'
    foreach ($k in $runKeys) {
        if (-not (Test-Path $k)) { continue }
        $props = Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        $props.PSObject.Properties |
            Where-Object { $_.Name -notmatch '^PS' -and $_.Value -match $pattern } |
            ForEach-Object {
                Remove-ItemProperty -Path $k -Name $_.Name -ErrorAction SilentlyContinue
                Write-Log "Removed startup item '$($_.Name)' from $k" INFO
            }
    }
}

function Set-ServiceManualSafely {
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { return }
    if ($svc.StartType -eq 'Automatic') {
        Set-Service -Name $Name -StartupType Manual -ErrorAction SilentlyContinue
        Write-Log "Service '$Name' set to Manual." INFO
    }
}

Assert-IsAdmin
Start-Log -Name 'optimize'

Clear-TempFiles
Set-PowerPlanHighPerformance
Disable-UnnecessaryStartupItems

foreach ($s in @('DiagTrack','dmwappushservice','WSearch')) {
    Set-ServiceManualSafely -Name $s
}

Write-Log 'Performance optimization completed.' SUCCESS