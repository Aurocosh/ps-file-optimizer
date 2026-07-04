BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Get-ImageTestCorpus.ps1' -Tag Unit {
    It 'Verifies Tier A committed fixtures' {
        $scriptPath = Join-Path (Get-FoTestModuleRoot) 'Scripts\Get-ImageTestCorpus.ps1'
        $result = & $scriptPath -Tier A
        $result.Verified | Should -Be $true
        $result.FileCount | Should -BeGreaterThan 30
    }
}
