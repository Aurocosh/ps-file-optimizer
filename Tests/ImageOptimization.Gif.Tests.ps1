$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

. "$PSScriptRoot\TestHelpers.ps1"

Describe 'GIF lossless optimization' -Tag ImageIntegration {
    BeforeAll {
        if (-not (Test-FoPluginsAvailable)) {
            Set-TestInconclusive 'Plugin binaries not found. Set FO_TEST_PLUGIN_PATH.'
            return
        }
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'gif'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Optimizes gif-palette256 with pixel compare' {
        if (-not $script:Settings) { return }

        $result = Invoke-FoImageOptimizationTest -FixtureId 'gif-palette256' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir

        Assert-FoImageOptimizationResult -Result $result -RequireCompare
    }

    It 'Optimizes gif-anim3 and preserves all frames' {
        if (-not $script:Settings) { return }

        $result = Invoke-FoImageOptimizationTest -FixtureId 'gif-anim3' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory (Join-Path $script:WorkDir 'anim3')

        Assert-FoImageOptimizationResult -Result $result

        $frameCompare = Compare-FoGifFrames -Before $result.BeforePath -After $result.AfterPath `
            -PluginPath $script:PluginPath -WorkDirectory (Join-Path $script:WorkDir 'anim3-frames')

        $frameCompare.Pass | Should -Be $true
        ($frameCompare.BeforeCount -gt 1) | Should -Be $true
        $frameCompare.BeforeCount | Should -Be $frameCompare.AfterCount
        ($frameCompare.FrameResults | Where-Object { -not $_.Pass }).Count | Should -Be 0
    }
}
