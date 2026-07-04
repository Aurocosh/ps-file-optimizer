$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

. "$PSScriptRoot\TestHelpers.ps1"

Describe 'ICO lossless optimization' -Tag ImageIntegration {
    BeforeAll {
        if (-not (Test-FoPluginsAvailable)) {
            Set-TestInconclusive 'Plugin binaries not found. Set FO_TEST_PLUGIN_PATH.'
            return
        }
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'ico'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Compares largest embedded icon only (ico-smile)' {
        if (-not $script:Settings) { return }

        $result = Invoke-FoImageOptimizationTest -FixtureId 'ico-smile' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory (Join-Path $script:WorkDir 'smile') -SkipCompare

        Assert-FoImageOptimizationResult -Result $result

        $icoCompare = Compare-FoIcoLargest -Before $result.BeforePath -After $result.AfterPath `
            -PluginPath $script:PluginPath -WorkDirectory (Join-Path $script:WorkDir 'smile-largest')

        $icoCompare.Pass | Should Be $true
        $icoCompare.BeforeIndex | Should Be (Get-FoIcoLargestIndex -Path $result.BeforePath -PluginPath $script:PluginPath)
    }

    It 'Optimizes ico-png32 multi-entry icon via largest embedded compare' {
        if (-not $script:Settings) { return }

        $result = Invoke-FoImageOptimizationTest -FixtureId 'ico-png32' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory (Join-Path $script:WorkDir 'png32') -SkipCompare

        Assert-FoImageOptimizationResult -Result $result

        $icoCompare = Compare-FoIcoLargest -Before $result.BeforePath -After $result.AfterPath `
            -PluginPath $script:PluginPath -WorkDirectory (Join-Path $script:WorkDir 'png32-largest')

        $icoCompare.Pass | Should Be $true
    }
}
