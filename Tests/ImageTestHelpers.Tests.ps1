BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Image test manifest and fixtures' -Tag Unit {
    It 'Loads FO-ImageTest-v1 manifest' {
        $manifest = Get-FoImageTestManifest
        $manifest.Version | Should -Be 'FO-ImageTest-v1'
        @($manifest.Tiers.A.Files).Count | Should -Be 34
    }

    It 'Resolves fixture path by id' {
        $path = Get-FoImageTestFixturePath -Id 'png-basn2c08'
        $path | Should -Match 'pngsuite[\\/]basn2c08\.png$'
        Test-Path -LiteralPath $path | Should -Be $true
    }

    It 'Reports Tier A fixtures present' {
        $check = Test-FoImageTestFixturesPresent -Tier A
        $check.Present | Should -Be $true
        $check.Missing.Count | Should -Be 0
        $check.Count | Should -Be 34
    }

    It 'Copies fixture without mutating source' {
        $source = Get-FoImageTestFixturePath -Id 'png-basn0g08'
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $dest = Join-Path $TestDrive 'copy-basn0g08.png'

        Copy-FoImageFixture -Id 'png-basn0g08' -Destination $dest | Should -Be $dest
        Test-Path -LiteralPath $dest | Should -Be $true
        (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash | Should -Be $sourceHash
    }
}

Describe 'Image test profiles' -Tag Unit {
    It 'Builds LosslessDefault settings from profile' {
        $settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath (Join-Path $TestDrive 'fake-plugins')
        $settings.Level | Should -Be 5
        $settings.OutputMode | Should -Be 'Replace'
        $settings.PNGAllowLossy | Should -Be $false
        $settings.JPEGAllowLossy | Should -Be $false
        $settings.HistoryEnabled | Should -Be $false
        $settings.PluginSearchMode | Should -Be 'PortableOnly'
        $settings.ContainsKey('CompareMode') | Should -Be $false
        Get-FoImageTestProfileCompareMode -Name 'LosslessDefault' | Should -Be 'Pixel'
    }

    It 'Uses fixture LossySSIMMaximum override when set' {
        Get-FoImageTestLossyThreshold -ProfileName 'LossyHighQuality' -Format 'PNG' `
            -FixtureOverride 1.05 | Should -Be 1.05
    }

    It 'Uses PNGMicro threshold for small PNG fixtures' {
        Mock Get-FoImageInfo { return @{ Width = 32; Height = 32; Format = 'PNG' } }
        $path = Get-FoImageTestFixturePath -Id 'png-basn0g04'
        Get-FoImageTestLossyThreshold -ProfileName 'LossyHighQuality' -Format 'PNG' `
            -ImagePath $path -PluginPath (Join-Path $TestDrive 'plugins') | Should -Be 0.8
    }

    It 'Maps JPG extension format to JPEG threshold' {
        Get-FoImageTestLossyThreshold -ProfileName 'LossyHighQuality' -Format 'JPG' | Should -Be 0.02
    }

    It 'Resolves manifest LossySSIMMaximum by fixture id' {
        Get-FoImageTestLossyFixtureOverride -FixtureId 'png-basn3p04' | Should -Be 1.05
    }

    It 'Resolves Tier B path override from ImageTestLossyOverrides.psd1' {
        Get-FoImageTestLossyFixtureOverride -RelativePath 'gb82-sc/graph.png' | Should -Be 1.40
    }

    It 'Builds LossyHighQuality settings from profile' {
        $settings = Get-FoImageTestProfile -Name 'LossyHighQuality'
        $settings.Level | Should -Be 9
        $settings.PNGAllowLossy | Should -Be $true
        $settings.JPEGAllowLossy | Should -Be $true
        $settings.ContainsKey('CompareMode') | Should -Be $false
        Get-FoImageTestProfileCompareMode -Name 'LossyHighQuality' | Should -Be 'SSIMOnly'
    }
}

Describe 'Image test failure artifacts' -Tag Unit {
    It 'Builds default artifact paths under the work directory' {
        $workRoot = Join-Path $TestDrive 'run1'
        $paths = Get-FoImageTestArtifactPaths -WorkRoot $workRoot -FileName 'sample.png'
        $paths.Root | Should -Be (Join-Path $workRoot 'artifacts')
        $paths.DiffPath | Should -Be (Join-Path $workRoot 'artifacts\diffs\sample_diff.png')
        $paths.IdentifyDir | Should -Be (Join-Path $workRoot 'artifacts\identify')
        $paths.LogPath | Should -Be (Join-Path $workRoot 'artifacts\optimization.txt')
    }
}

Describe 'Invoke-FoImageOptimizationTest' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
    }

    It 'Optimizes jpg-testorig and passes pixel compare' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'jpg-testorig' -Settings $script:Settings -CompareMode Pixel

        (Test-FoImageOptimizationResult -Result $result -RequireCompare) | Should -Be $true
        if ($result.Optimization.Status -eq 'Optimized') {
            ($result.Optimization.FinalSize -lt $result.Optimization.OriginalSize) | Should -Be $true
        }
    }
}
