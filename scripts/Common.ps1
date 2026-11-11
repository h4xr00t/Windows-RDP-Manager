#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:DefaultConfigPath = Join-Path -Path $env:ProgramData -ChildPath 'RDPManager\config.xml'

function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-IsAdmin {
    if (-not (Test-IsAdmin)) {
        throw 'Administrator privileges required. Run PowerShell as Administrator.'
    }
}

$script:LogDirectory = Join-Path -Path $env:ProgramData -ChildPath 'RDPManager\Logs'
$script:LogFilePath  = $null

function Start-Log {
    param([string]$Name = 'rdp-manager')
    if (-not (Test-Path -LiteralPath $script:LogDirectory)) {
        New-Item -ItemType Directory -Path $script:LogDirectory -Force | Out-Null
    }
    $script:LogFilePath = Join-Path -Path $script:LogDirectory -ChildPath (
        "{0}-{1}.log" -f $Name, (Get-Date -Format 'yyyyMMdd-HHmmss')
    )
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')][string]$Level = 'INFO'
    )
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    if ($script:LogFilePath) {
        Add-Content -LiteralPath $script:LogFilePath -Value $line -Encoding UTF8
    }
    $color = @{ INFO='Cyan'; WARN='Yellow'; ERROR='Red'; SUCCESS='Green' }[$Level]
    Write-Host $line -ForegroundColor $color
}

function ConvertTo-PlainText {
    [CmdletBinding()]
    param([Parameter(Mandatory)][SecureString]$SecureString)

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Read-PlainPassword {
    [CmdletBinding()]
    param([string]$Prompt = 'Enter password')

    $secure = Read-Host -Prompt $Prompt -AsSecureString
    return ConvertTo-PlainText -SecureString $secure
}

function Get-RDPManagerConfig {
    [CmdletBinding()]
    param([string]$Path = $script:DefaultConfigPath)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return Import-Clixml -LiteralPath $Path
}

function Save-RDPManagerConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]$Config,
        [string]$Path = $script:DefaultConfigPath
    )

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (-not $PSCmdlet.ShouldProcess($Path, 'Save configuration')) { return }

    $Config | Export-Clixml -LiteralPath $Path -Depth 5

    $acl = Get-Acl -LiteralPath $Path
    $acl.SetAccessRuleProtection($true, $false)
    $adminSid  = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $systemSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($adminSid,  'FullControl', 'Allow')))
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($systemSid, 'FullControl', 'Allow')))
    Set-Acl -LiteralPath $Path -AclObject $acl
}