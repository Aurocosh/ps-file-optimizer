BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'TIFF lossless optimization' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'tiff'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Optimizes tiff-l1 with pixel compare' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'tiff-l1' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir

        (Test-FoImageOptimizationResult -Result $result -RequireCompare) | Should -Be $true
    }
}
