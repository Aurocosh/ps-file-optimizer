BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'WebP lossless optimization' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'webp'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Optimizes webp-lossless with pixel compare' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'webp-lossless' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir

        (Test-FoImageOptimizationResult -Result $result -RequireCompare) | Should -Be $true
    }
}
