$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

. "$PSScriptRoot\TestHelpers.ps1"

Describe 'WebP lossless optimization' -Tag ImageIntegration {
    BeforeAll {
        if (-not (Test-FoPluginsAvailable)) {
            Set-TestInconclusive 'Plugin binaries not found. Set FO_TEST_PLUGIN_PATH.'
            return
        }
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'webp'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Optimizes webp-lossless with pixel compare' {
        if (-not $script:Settings) { return }

        $result = Invoke-FoImageOptimizationTest -FixtureId 'webp-lossless' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir

        Assert-FoImageOptimizationResult -Result $result -RequireCompare
    }
}
