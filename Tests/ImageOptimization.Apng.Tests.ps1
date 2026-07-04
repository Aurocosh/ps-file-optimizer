BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'APNG lossless optimization' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable -RequiredExecutables @('magick.exe', 'ffmpeg.exe'))) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'apng'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Optimizes apng-dispose with pixel compare' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'apng-dispose' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory (Join-Path $script:WorkDir 'dispose')

        (Test-FoImageOptimizationResult -Result $result -RequireCompare) | Should -Be $true
    }

    It 'Optimizes apng-3frame preserving visual content' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'apng-3frame' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory (Join-Path $script:WorkDir '3frame') -SkipCompare

        (Test-FoImageOptimizationResult -Result $result) | Should -Be $true

        $beforeCount = Get-FoApngFrameCount -Path $result.BeforePath -PluginPath $script:PluginPath `
            -WorkDirectory (Join-Path $script:WorkDir '3frame-before-count')
        ($beforeCount -gt 1) | Should -Be $true

        $afterCount = Get-FoApngFrameCount -Path $result.AfterPath -PluginPath $script:PluginPath `
            -WorkDirectory (Join-Path $script:WorkDir '3frame-after-count')

        if ($afterCount -eq $beforeCount) {
            $frameCompare = Compare-FoApngFrames -Before $result.BeforePath -After $result.AfterPath `
                -PluginPath $script:PluginPath -WorkDirectory (Join-Path $script:WorkDir '3frame-frames')
            $frameCompare.Pass | Should -Be $true
        }
        else {
            $afterCount | Should -Be 1
            $staticCompare = Compare-FoImage -Before $result.BeforePath -After $result.AfterPath `
                -Mode Pixel -PluginPath $script:PluginPath
            $staticCompare.Pass | Should -Be $true
        }
    }
}
