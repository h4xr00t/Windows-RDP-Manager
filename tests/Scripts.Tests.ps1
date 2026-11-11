#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Script files' {

    BeforeAll {
        $scriptRoot = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\scripts')).Path
    }

    It 'scripts directory exists' {
        $scriptRoot | Should -Exist
    }

    It 'All expected scripts exist' {
        $expected = @(
            'Common.ps1'
            'Initialize-Config.ps1'
            'Setup-RDP.ps1'
            'Setup-User.ps1'
            'Setup-Tailscale.ps1'
            'Cleanup-System.ps1'
            'Optimize-Performance.ps1'
            'Manage-Session.ps1'
            'Manage-Workspace.ps1'
            'Invoke-RDPManager.ps1'
        )
        foreach ($e in $expected) {
            (Join-Path -Path $scriptRoot -ChildPath $e) | Should -Exist -Because "$e is part of the project"
        }
    }

    It 'Scripts parse without syntax errors' {
        $files = Get-ChildItem -Path $scriptRoot -Filter *.ps1
        $files.Count | Should -BeGreaterThan 0

        foreach ($f in $files) {
            $tokens      = $null
            $parseErrors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $f.FullName, [ref]$tokens, [ref]$parseErrors
            ) | Out-Null
            $parseErrors.Count | Should -Be 0 -Because "$($f.Name) should parse without errors"
        }
    }
}