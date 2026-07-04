BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'AVIF optimization' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:Threshold = (Get-FoImageTestDecisions).AvifDefaultSSIMDissimilarityMaximum
        $script:WorkDir = Join-Path $TestDrive 'avif'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Optimizes avif-white-1x1 within default SSIM threshold' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'avif-white-1x1' -Settings $script:Settings `
            -CompareMode SSIMOnly -SSIMDissimilarityMaximum $script:Threshold -WorkDirectory $script:WorkDir

        @('Optimized', 'Unchanged') -contains $result.Optimization.Status | Should -Be $true
        $result.Compare.Pass | Should -Be $true
        ($result.Compare.MetricValue -le $script:Threshold) | Should -Be $true
        $result.Pass | Should -Be $true
    }
}
