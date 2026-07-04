$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

. "$PSScriptRoot\TestHelpers.ps1"

Describe 'LossyHighQuality profile' -Tag ImageIntegration, Lossy {
    BeforeAll {
        if (-not (Test-FoPluginsAvailable)) {
            Set-TestInconclusive 'Plugin binaries not found. Set FO_TEST_PLUGIN_PATH.'
            return
        }
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LossyHighQuality' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'lossy'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Enables lossy flags and level 9' {
        if (-not $script:Settings) { return }

        $script:Settings.Level | Should -Be 9
        $script:Settings.PNGAllowLossy | Should -Be $true
        $script:Settings.JPEGAllowLossy | Should -Be $true
        $script:Settings.GIFAllowLossy | Should -Be $true
        $script:Settings.WEBPAllowLossy | Should -Be $true
    }

    foreach ($case in @(
            @{ FixtureId = 'jpg-testorig'; Format = 'JPEG' }
            @{ FixtureId = 'jpg-prog-rst'; Format = 'JPEG' }
        )) {
        It "Optimizes $($case.FixtureId) within JPEG SSIM threshold" {
            if (-not $script:Settings) { return }

            $threshold = Get-FoImageTestLossyThreshold -ProfileName 'LossyHighQuality' -Format $case.Format
            $result = Invoke-FoLossyImageOptimizationTest -FixtureId $case.FixtureId -Format $case.Format `
                -Settings $script:Settings -WorkDirectory (Join-Path $script:WorkDir $case.FixtureId)

            Assert-FoLossyOptimizationResult -Result $result -SSIMDissimilarityMaximum $threshold
        }
    }

    It 'Optimizes a generated PNG within PNG SSIM threshold' {
        if (-not $script:Settings) { return }

        $fixture = Join-Path $script:WorkDir 'lossy-source-256.png'
        New-FoTestPng -Path $fixture -Width 256 -Height 256
        $threshold = Get-FoImageTestLossyThreshold -ProfileName 'LossyHighQuality' -Format 'PNG'

        $result = Invoke-FoLossyImageOptimizationTest -FixturePath $fixture -Format 'PNG' `
            -Settings $script:Settings -WorkDirectory (Join-Path $script:WorkDir 'png256')

        Assert-FoLossyOptimizationResult -Result $result -SSIMDissimilarityMaximum $threshold
    }

    It 'Optimizes gif-anim3 within GIF SSIM threshold' {
        if (-not $script:Settings) { return }

        $threshold = Get-FoImageTestLossyThreshold -ProfileName 'LossyHighQuality' -Format 'GIF'
        $result = Invoke-FoLossyImageOptimizationTest -FixtureId 'gif-anim3' -Format 'GIF' `
            -Settings $script:Settings -WorkDirectory (Join-Path $script:WorkDir 'gif-anim3')

        Assert-FoLossyOptimizationResult -Result $result -SSIMDissimilarityMaximum $threshold
    }

    It 'Optimizes webp-lossy within WebP SSIM threshold' {
        if (-not $script:Settings) { return }

        $threshold = Get-FoImageTestLossyThreshold -ProfileName 'LossyHighQuality' -Format 'WebP'
        $result = Invoke-FoLossyImageOptimizationTest -FixtureId 'webp-lossy' -Format 'WebP' `
            -Settings $script:Settings -WorkDirectory (Join-Path $script:WorkDir 'webp-lossy')

        Assert-FoLossyOptimizationResult -Result $result -SSIMDissimilarityMaximum $threshold
    }
}
