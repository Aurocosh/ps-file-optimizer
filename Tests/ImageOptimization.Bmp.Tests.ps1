$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

. "$PSScriptRoot\TestHelpers.ps1"

Describe 'BMP lossless optimization' -Tag ImageIntegration {
    BeforeAll {
        if (-not (Test-FoPluginsAvailable)) {
            Set-TestInconclusive 'Plugin binaries not found. Set FO_TEST_PLUGIN_PATH.'
            return
        }
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'bmp'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    foreach ($fixtureId in @('bmp-rle', 'bmp-1bit')) {
        It "Optimizes $fixtureId with pixel compare" {
            if (-not $script:Settings) { return }

            $result = Invoke-FoImageOptimizationTest -FixtureId $fixtureId -Settings $script:Settings `
                -CompareMode Pixel -WorkDirectory $script:WorkDir

            Assert-FoImageOptimizationResult -Result $result -RequireCompare
        }
    }
}
