#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Common functions' {

    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\scripts\Common.ps1')
    }

    It 'Test-IsAdmin returns a boolean' {
        Test-IsAdmin | Should -BeOfType ([bool])
    }

    It 'Write-Log does not throw' {
        { Write-Log -Message 'pester-test-message' -Level INFO } | Should -Not -Throw
    }

    It 'Write-Log accepts all valid levels' {
        foreach ($lvl in @('INFO','WARN','ERROR','SUCCESS')) {
            { Write-Log -Message "level=$lvl" -Level $lvl } | Should -Not -Throw
        }
    }

    It 'ConvertTo-PlainText command exists' {
        Get-Command -Name ConvertTo-PlainText -ErrorAction SilentlyContinue |
            Should -Not -BeNullOrEmpty
    }

    It 'ConvertTo-PlainText round-trips a string' {
        $plain  = 'test-value-123'
        $secure = ConvertTo-SecureString -String $plain -AsPlainText -Force
        ConvertTo-PlainText -SecureString $secure | Should -Be $plain
    }

    It 'Read-PlainPassword command exists' {
        Get-Command -Name Read-PlainPassword -ErrorAction SilentlyContinue |
            Should -Not -BeNullOrEmpty
    }

    It 'Assert-IsAdmin command exists' {
        Get-Command -Name Assert-IsAdmin -ErrorAction SilentlyContinue |
            Should -Not -BeNullOrEmpty
    }

    It 'Get-RDPManagerConfig command exists' {
        Get-Command -Name Get-RDPManagerConfig -ErrorAction SilentlyContinue |
            Should -Not -BeNullOrEmpty
    }

    It 'Save-RDPManagerConfig command exists' {
        Get-Command -Name Save-RDPManagerConfig -ErrorAction SilentlyContinue |
            Should -Not -BeNullOrEmpty
    }
}