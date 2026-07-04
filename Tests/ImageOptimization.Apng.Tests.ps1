$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

. "$PSScriptRoot\TestHelpers.ps1"

Describe 'APNG lossless optimization' -Tag ImageIntegration {
    BeforeAll {
        if (-not (Test-FoPluginsAvailable)) {
            Set-TestInconclusive 'Plugin binaries not found. Set FO_TEST_PLUGIN_PATH.'
            return
        }
        if (-not (Test-FoPluginsAvailable -RequiredExecutables @('ffmpeg.exe'))) {
            Set-TestInconclusive 'ffmpeg.exe required for APNG frame compare.'
            return
        }
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'apng'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Optimizes apng-dispose with pixel compare' {
        if (-not $script:Settings) { return }

        $result = Invoke-FoImageOptimizationTest -FixtureId 'apng-dispose' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory (Join-Path $script:WorkDir 'dispose')

        Assert-FoImageOptimizationResult -Result $result -RequireCompare
    }

    It 'Optimizes apng-3frame preserving visual content' {
        if (-not $script:Settings) { return }

        $result = Invoke-FoImageOptimizationTest -FixtureId 'apng-3frame' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory (Join-Path $script:WorkDir '3frame') -SkipCompare

        Assert-FoImageOptimizationResult -Result $result

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
            # Full PNG chain may flatten animated APNG to a static PNG (acTL removed).
            $afterCount | Should -Be 1
            $staticCompare = Compare-FoImage -Before $result.BeforePath -After $result.AfterPath `
                -Mode Pixel -PluginPath $script:PluginPath
            $staticCompare.Pass | Should -Be $true
        }
    }
}
