#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'Common.ps1')

$AppsToRemove = @(
    'Discord'
    'Telegram'
    'Unity'
    'Unity Hub'
    'Epic Games Launcher'
    'Mozilla Firefox'
    'Google Chrome'
    '7-Zip'
)

function Get-UninstallEntry {
    [CmdletBinding()]
    param()

    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($p in $paths) {
        Get-ItemProperty -Path $p -ErrorAction SilentlyContinue |
            ForEach-Object {
                $displayProp = $_.PSObject.Properties['DisplayName']
                if (-not $displayProp -or [string]::IsNullOrWhiteSpace($displayProp.Value)) {
                    return
                }
                $uninstallProp = $_.PSObject.Properties['UninstallString']
                $quietProp     = $_.PSObject.Properties['QuietUninstallString']
                [PSCustomObject]@{
                    DisplayName          = $displayProp.Value
                    UninstallString      = if ($uninstallProp) { $uninstallProp.Value } else { $null }
                    QuietUninstallString = if ($quietProp)     { $quietProp.Value }     else { $null }
                }
            }
    }
}

function Remove-AppIfInstalled {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([Parameter(Mandatory)][string]$Name)

    $appx = Get-AppxPackage -Name "*$Name*" -ErrorAction SilentlyContinue
    foreach ($pkg in $appx) {
        if ($PSCmdlet.ShouldProcess($pkg.PackageFullName, 'Remove Appx package')) {
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Log "Removed Appx $($pkg.PackageFullName)" SUCCESS
            } catch {
                Write-Log "Failed to remove Appx $($pkg.PackageFullName): $_" WARN
            }
        }
    }

    $entries = Get-UninstallEntry | Where-Object { $_.DisplayName -like "*$Name*" }
    foreach ($entry in $entries) {
        $cmd = if ($entry.QuietUninstallString) { $entry.QuietUninstallString } else { $entry.UninstallString }
        if (-not $cmd) { continue }
        if (-not $PSCmdlet.ShouldProcess($entry.DisplayName, 'Uninstall application')) { continue }

        Write-Log "Uninstalling '$($entry.DisplayName)'..."
        try {
            if ($cmd -match '^"([^"]+)"\s*(.*)$') {
                $exe     = $matches[1]
                $argLine = $matches[2]
                if ($exe -match 'msiexec') {
                    Start-Process -FilePath $exe -ArgumentList ($argLine + ' /qn /norestart') -Wait -NoNewWindow
                } else {
                    Start-Process -FilePath $exe -ArgumentList $argLine -Wait -NoNewWindow
                }
            } else {
                cmd.exe /c $cmd /S | Out-Null
            }
            Write-Log "Uninstall completed for '$($entry.DisplayName)'." SUCCESS
        } catch {
            Write-Log "Failed to uninstall '$($entry.DisplayName)': $_" WARN
        }
    }
}

function Remove-ProjectArtifact {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $files = @('Downloads.bat','wall.bat','msg.ps1','run.ps1','VMQuickConfig.exe')
    $dirs  = @('WindowsStress')

    $projectRoot = Split-Path -Parent $PSScriptRoot
    $roots = @(
        $projectRoot
        (Join-Path -Path $env:USERPROFILE -ChildPath 'Desktop')
        (Join-Path -Path $env:USERPROFILE -ChildPath 'Downloads')
        (Join-Path -Path $env:USERPROFILE -ChildPath 'Documents')
        'C:\RDP-Workspace'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

    foreach ($root in $roots) {
        foreach ($name in $files) {
            Get-ChildItem -LiteralPath $root -Filter $name -File -Recurse -ErrorAction SilentlyContinue |
                ForEach-Object {
                    if ($PSCmdlet.ShouldProcess($_.FullName, 'Delete file')) {
                        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                        Write-Log "Deleted file $($_.FullName)" SUCCESS
                    }
                }
        }
        foreach ($d in $dirs) {
            Get-ChildItem -LiteralPath $root -Filter $d -Directory -Recurse -ErrorAction SilentlyContinue |
                ForEach-Object {
                    if ($PSCmdlet.ShouldProcess($_.FullName, 'Delete directory')) {
                        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Log "Deleted directory $($_.FullName)" SUCCESS
                    }
                }
        }
    }

    $picRoots = @(
        (Join-Path -Path $env:USERPROFILE -ChildPath 'Pictures')
        (Join-Path -Path $env:USERPROFILE -ChildPath 'Desktop')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

    foreach ($pic in $picRoots) {
        Get-ChildItem -LiteralPath $pic -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|bmp)$' -and $_.BaseName -match 'wall|wallpaper' } |
            ForEach-Object {
                if ($PSCmdlet.ShouldProcess($_.FullName, 'Delete wallpaper file')) {
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                    Write-Log "Deleted wallpaper $($_.FullName)" SUCCESS
                }
            }
    }
}

Assert-IsAdmin
Start-Log -Name 'cleanup'
Write-Log 'Starting cleanup.'

foreach ($app in $AppsToRemove) {
    Write-Log "Checking for '$app'..."
    Remove-AppIfInstalled -Name $app
}

Remove-ProjectArtifact

Write-Log 'Cleanup completed.' SUCCESS
