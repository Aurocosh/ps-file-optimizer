BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'BMP lossless optimization' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'bmp'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    foreach ($fixtureId in @('bmp-rle', 'bmp-1bit')) {
        It "Optimizes $fixtureId with pixel compare" {
            $result = Invoke-FoImageOptimizationTest -FixtureId $fixtureId -Settings $script:Settings `
                -CompareMode Pixel -WorkDirectory $script:WorkDir

            (Test-FoImageOptimizationResult -Result $result -RequireCompare) | Should -Be $true
        }
    }
}
