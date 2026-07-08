BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Image optimization smoke' -Tag ImageIntegration, Smoke -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $workRoot = if ($env:FO_TEST_ARTIFACT_DIR) { $env:FO_TEST_ARTIFACT_DIR } else { $TestDrive }
        $script:WorkDir = Join-Path $workRoot 'image-smoke'
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

    It 'Optimizes JPEG fixture jpg-gray-square' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'jpg-gray-square' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir

        (Test-FoImageOptimizationResult -Result $result -RequireCompare) | Should -Be $true
    }

    It 'Optimizes WebP fixture webp-lossless with pixel compare' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'webp-lossless' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir

        (Test-FoImageOptimizationResult -Result $result -RequireCompare) | Should -Be $true
    }
}
