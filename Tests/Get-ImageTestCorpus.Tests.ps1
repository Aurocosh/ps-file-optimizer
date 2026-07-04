$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

Describe 'Get-ImageTestCorpus.ps1' {
    It 'Verifies Tier A committed fixtures' {
        $scriptPath = Join-Path $moduleRoot 'Scripts\Get-ImageTestCorpus.ps1'
        $result = & $scriptPath -Tier A
        $result.Verified | Should Be $true
        $result.FileCount | Should BeGreaterThan 30
    }
}
