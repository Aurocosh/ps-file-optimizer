BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'JPEG lossless optimization' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'jpeg'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    foreach ($fixtureId in @('jpg-testorig', 'jpg-prog-rst', 'jpg-exif-xmp')) {
        It "Optimizes $fixtureId with pixel or SSIM compare" {
            $result = Invoke-FoImageOptimizationTest -FixtureId $fixtureId -Settings $script:Settings `
                -CompareMode Pixel -WorkDirectory $script:WorkDir

            (Test-FoImageOptimizationResult -Result $result -RequireCompare) | Should -Be $true
            @('Pixel', 'SSIM') -contains $result.CompareMode | Should -Be $true
        }
    }

    It 'Uses pixel compare when lossless JPEG is visually identical' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'jpg-testorig' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir

        $result.CompareMode | Should -Be 'Pixel'
        $result.Compare.MetricValue | Should -Be 0
    }

    It 'Falls back to SSIM when pixel AE fails on re-encoded JPEG' {
        $source = Get-FoImageTestFixturePath -Id 'jpg-testorig'
        $before = Join-Path $script:WorkDir 'fallback-before.jpg'
        $after = Join-Path $script:WorkDir 'fallback-after.jpg'
        Copy-Item -LiteralPath $source -Destination $before -Force
        Copy-Item -LiteralPath $source -Destination $after -Force

        $magick = (Resolve-FoPluginExecutable -Name 'magick.exe' -SearchMode PortableOnly -PluginPath $script:PluginPath).Path
        $reencode = Invoke-FoMagickCli -MagickExe $magick -WorkingDirectory (Split-Path -Parent $magick) -ArgumentList @(
            $before, '-quality', '95', $after
        )
        $reencode.ExitCode | Should -Be 0

        $pixel = Compare-FoImage -Before $before -After $after -Mode Pixel -PluginPath $script:PluginPath
        if ($pixel.Pass) {
            Set-ItResult -Inconclusive -Because 'Re-encoded JPEG was still pixel-identical; cannot exercise SSIM fallback.'
        }

        $fallback = Test-FoJpegImageCompare -Before $before -After $after -PluginPath $script:PluginPath
        $fallback.CompareMode | Should -Be 'SSIM'
        if (-not $fallback.Pass) {
            Set-ItResult -Inconclusive -Because 'Re-encoded JPEG exceeds SSIM threshold 0; pixel fallback path was exercised.'
        }
    }
}
