#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('Initialize','Backup','Restore')]
    [string]$Action = 'Initialize',
    [string]$Username = $env:RDP_USERNAME,
    [string]$BackupPath,
    [string]$RestoreFrom
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Common.ps1"

$WorkspaceRoot = 'C:\RDP-Workspace'
$BackupRoot    = 'C:\RDP-Workspace-Backups'

function Initialize-Workspace {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$UserName)

    if (-not (Test-Path -LiteralPath $WorkspaceRoot)) {
        if ($PSCmdlet.ShouldProcess($WorkspaceRoot, 'Create workspace directory')) {
            New-Item -ItemType Directory -Path $WorkspaceRoot -Force | Out-Null
            Write-Log "Created workspace $WorkspaceRoot" SUCCESS
        }
    } else {
        Write-Log "Workspace exists: $WorkspaceRoot" INFO
    }

    foreach ($sub in @('Projects','Documents','Backups')) {
        $p = Join-Path -Path $WorkspaceRoot -ChildPath $sub
        if (-not (Test-Path -LiteralPath $p)) {
            if ($PSCmdlet.ShouldProcess($p, 'Create subdirectory')) {
                New-Item -ItemType Directory -Path $p -Force | Out-Null
            }
        }
    }

    if ($UserName) {
        $user = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
        if ($user) {
            $acl  = Get-Acl -LiteralPath $WorkspaceRoot
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                "$env:COMPUTERNAME\$UserName", 'Modify',
                'ContainerInherit,ObjectInherit', 'None', 'Allow'
            )
            $acl.SetAccessRule($rule)
            Set-Acl -LiteralPath $WorkspaceRoot -AclObject $acl
            Write-Log "Granted Modify on workspace to $UserName" SUCCESS
        } else {
            Write-Log "User '$UserName' not found; ACL skipped." WARN
        }
    }

    if (-not (Test-Path -LiteralPath $BackupRoot)) {
        if ($PSCmdlet.ShouldProcess($BackupRoot, 'Create backup root')) {
            New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
        }
    }
}

function Backup-Workspace {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Destination)

    if (-not (Test-Path -LiteralPath $WorkspaceRoot)) {
        throw "Workspace $WorkspaceRoot does not exist."
    }

    if (-not $Destination) {
        if (-not (Test-Path -LiteralPath $BackupRoot)) {
            New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
        }
        $Destination = Join-Path -Path $BackupRoot -ChildPath (
            "workspace-{0}.zip" -f (Get-Date -Format 'yyyyMMdd-HHmmss')
        )
    }

    if (-not $PSCmdlet.ShouldProcess($Destination, 'Backup workspace')) { return }

    Compress-Archive -Path (Join-Path -Path $WorkspaceRoot -ChildPath '*') `
        -DestinationPath $Destination -CompressionLevel Optimal -Force
    Write-Log "Workspace backed up to $Destination" SUCCESS
}

function Restore-Workspace {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Source)

    if (-not $Source) { throw 'RestoreFrom path is required.' }
    if (-not (Test-Path -LiteralPath $Source)) { throw "Backup not found: $Source" }

    if (Test-Path -LiteralPath $WorkspaceRoot) {
        if (-not (Test-Path -LiteralPath $BackupRoot)) {
            New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
        }
        $safety = Join-Path -Path $BackupRoot -ChildPath (
            "pre-restore-{0}.zip" -f (Get-Date -Format 'yyyyMMdd-HHmmss')
        )
        Write-Log 'Creating safety backup before restore...'
        Compress-Archive -Path (Join-Path -Path $WorkspaceRoot -ChildPath '*') `
            -DestinationPath $safety -CompressionLevel Optimal -Force
    } else {
        New-Item -ItemType Directory -Path $WorkspaceRoot -Force | Out-Null
    }

    if (-not $PSCmdlet.ShouldProcess($WorkspaceRoot, 'Restore workspace from backup')) { return }

    Expand-Archive -LiteralPath $Source -DestinationPath $WorkspaceRoot -Force
    Write-Log "Workspace restored from $Source" SUCCESS
}

Start-Log -Name 'workspace'

switch ($Action) {
    'Initialize' { Initialize-Workspace -UserName $Username }
    'Backup'     { Backup-Workspace     -Destination $BackupPath }
    'Restore'    { Restore-Workspace    -Source $RestoreFrom }
    default      { throw "Unknown action: $Action" }
}