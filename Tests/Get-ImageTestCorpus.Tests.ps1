$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

. (Join-Path $moduleRoot 'Tests\ImageTestHelpers.ps1')
. (Join-Path $moduleRoot 'Private\Get-FoImageTestTierFiles.ps1')

Describe 'Get-FoImageTestTierRelativePaths' {
    It 'Selects expected Tier B file count when codec-corpus is available' {
        $upstream = 'D:\Projects\External\codec-corpus'
        if (-not (Test-Path -LiteralPath $upstream)) {
            Set-TestInconclusive 'codec-corpus clone not found at D:\Projects\External\codec-corpus'
        }

        $paths = Get-FoImageTestTierRelativePaths -Tier B -UpstreamRoot $upstream
        $paths.Count | Should BeGreaterThan 250
        ($paths -contains 'pngsuite/basn0g01.png') | Should Be $true
        ($paths | Where-Object { $_ -like 'pngsuite/x*' }).Count | Should Be 0
    }
}

Describe 'Get-ImageTestCorpus.ps1' {
    It 'Verifies Tier A committed fixtures' {
        $scriptPath = Join-Path $moduleRoot 'Scripts\Get-ImageTestCorpus.ps1'
        $result = & $scriptPath -Tier A
        $result.Verified | Should Be $true
        $result.FileCount | Should BeGreaterThan 30
    }
}
