BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'ICO lossless optimization' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'ico'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Compares largest embedded icon only (ico-smile)' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'ico-smile' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory (Join-Path $script:WorkDir 'smile') -SkipCompare

        (Test-FoImageOptimizationResult -Result $result) | Should -Be $true

        $icoCompare = Compare-FoIcoLargest -Before $result.BeforePath -After $result.AfterPath `
            -PluginPath $script:PluginPath -WorkDirectory (Join-Path $script:WorkDir 'smile-largest')

        $icoCompare.Pass | Should -Be $true
        $icoCompare.BeforeIndex | Should -Be (Get-FoIcoLargestIndex -Path $result.BeforePath -PluginPath $script:PluginPath)
    }

    It 'Optimizes ico-png32 multi-entry icon via largest embedded compare' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'ico-png32' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory (Join-Path $script:WorkDir 'png32') -SkipCompare

        (Test-FoImageOptimizationResult -Result $result) | Should -Be $true

        $icoCompare = Compare-FoIcoLargest -Before $result.BeforePath -After $result.AfterPath `
            -PluginPath $script:PluginPath -WorkDirectory (Join-Path $script:WorkDir 'png32-largest')

        $icoCompare.Pass | Should -Be $true
    }
}
