BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Image optimization smoke' -Tag ImageIntegration, Smoke -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'image-smoke'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Optimizes PNG fixture png-basn2c08 with pixel identity' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'png-basn2c08' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir

        (Test-FoImageOptimizationResult -Result $result -RequireCompare) | Should -Be $true
    }

    It 'Optimizes BMP fixture bmp-rle' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'bmp-rle' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir -SkipCompare

        (Test-FoImageOptimizationResult -Result $result -RequireSizeReduction) | Should -Be $true
    }

    It 'Optimizes GIF fixture gif-palette256' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'gif-palette256' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir -SkipCompare

        (Test-FoImageOptimizationResult -Result $result -RequireSizeReduction) | Should -Be $true
    }
}
