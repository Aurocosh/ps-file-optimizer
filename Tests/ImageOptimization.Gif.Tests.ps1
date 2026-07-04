BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'GIF lossless optimization' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'gif'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Optimizes gif-palette256 with pixel compare' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'gif-palette256' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir

        (Test-FoImageOptimizationResult -Result $result -RequireCompare) | Should -Be $true
    }

    It 'Optimizes gif-anim3 and preserves all frames' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'gif-anim3' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory (Join-Path $script:WorkDir 'anim3')

        (Test-FoImageOptimizationResult -Result $result) | Should -Be $true

        $frameCompare = Compare-FoGifFrames -Before $result.BeforePath -After $result.AfterPath `
            -PluginPath $script:PluginPath -WorkDirectory (Join-Path $script:WorkDir 'anim3-frames')

        $frameCompare.Pass | Should -Be $true
        ($frameCompare.BeforeCount -gt 1) | Should -Be $true
        $frameCompare.BeforeCount | Should -Be $frameCompare.AfterCount
        ($frameCompare.FrameResults | Where-Object { -not $_.Pass }).Count | Should -Be 0
    }
}
