BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'LossyHighQuality profile' -Tag ImageIntegration, Lossy -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LossyHighQuality' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'lossy'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Enables lossy flags and level 9' {
        $script:Settings.Level | Should -Be 9
        $script:Settings.PNGAllowLossy | Should -Be $true
        $script:Settings.JPEGAllowLossy | Should -Be $true
        $script:Settings.GIFAllowLossy | Should -Be $true
        $script:Settings.WEBPAllowLossy | Should -Be $true
    }

    It 'Optimizes <FixtureId> within <Format> SSIM threshold' -ForEach @(
            @{ FixtureId = 'jpg-testorig'; Format = 'JPEG' }
            @{ FixtureId = 'jpg-prog-rst'; Format = 'JPEG' }
        ) {
        $threshold = Get-FoImageTestLossyThreshold -ProfileName 'LossyHighQuality' -Format $_.Format
        $result = Invoke-FoLossyImageOptimizationTest -FixtureId $_.FixtureId -Format $_.Format `
            -Settings $script:Settings -WorkDirectory (Join-Path $script:WorkDir $_.FixtureId)

        (Test-FoLossyOptimizationResult -Result $result -SSIMDissimilarityMaximum $threshold) | Should -Be $true
    }

    It 'Optimizes a generated PNG within PNG SSIM threshold' {
        $fixture = Join-Path $script:WorkDir 'lossy-source-256.png'
        New-FoTestPng -Path $fixture -Width 256 -Height 256
        $threshold = Get-FoImageTestLossyThreshold -ProfileName 'LossyHighQuality' -Format 'PNG'

        $result = Invoke-FoLossyImageOptimizationTest -FixturePath $fixture -Format 'PNG' `
            -Settings $script:Settings -WorkDirectory (Join-Path $script:WorkDir 'png256')

        (Test-FoLossyOptimizationResult -Result $result -SSIMDissimilarityMaximum $threshold) | Should -Be $true
    }

    It 'Optimizes gif-anim3 within GIF SSIM threshold' {
        $threshold = Get-FoImageTestLossyThreshold -ProfileName 'LossyHighQuality' -Format 'GIF'
        $result = Invoke-FoLossyImageOptimizationTest -FixtureId 'gif-anim3' -Format 'GIF' `
            -Settings $script:Settings -WorkDirectory (Join-Path $script:WorkDir 'gif-anim3')

        (Test-FoLossyOptimizationResult -Result $result -SSIMDissimilarityMaximum $threshold) | Should -Be $true
    }

    It 'Optimizes webp-lossy within WebP SSIM threshold' {
        $threshold = Get-FoImageTestLossyThreshold -ProfileName 'LossyHighQuality' -Format 'WebP'
        $result = Invoke-FoLossyImageOptimizationTest -FixtureId 'webp-lossy' -Format 'WebP' `
            -Settings $script:Settings -WorkDirectory (Join-Path $script:WorkDir 'webp-lossy')

        (Test-FoLossyOptimizationResult -Result $result -SSIMDissimilarityMaximum $threshold) | Should -Be $true
    }
}
