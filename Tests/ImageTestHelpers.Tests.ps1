$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

. "$PSScriptRoot\TestHelpers.ps1"

Describe 'Image test manifest and fixtures' -Tag Unit {
    It 'Loads FO-ImageTest-v1 manifest' {
        $manifest = Get-FoImageTestManifest
        $manifest.Version | Should Be 'FO-ImageTest-v1'
        @($manifest.Tiers.A.Files).Count | Should Be 31
    }

    It 'Resolves fixture path by id' {
        $path = Get-FoImageTestFixturePath -Id 'png-basn2c08'
        $path | Should Match 'pngsuite[\\/]basn2c08\.png$'
        Test-Path -LiteralPath $path | Should Be $true
    }

    It 'Reports Tier A fixtures present' {
        $check = Test-FoImageTestFixturesPresent -Tier A
        $check.Present | Should Be $true
        $check.Missing.Count | Should Be 0
        $check.Count | Should Be 31
    }

    It 'Copies fixture without mutating source' {
        $source = Get-FoImageTestFixturePath -Id 'png-basn0g08'
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $dest = Join-Path $TestDrive 'copy-basn0g08.png'

        Copy-FoImageFixture -Id 'png-basn0g08' -Destination $dest | Should Be $dest
        Test-Path -LiteralPath $dest | Should Be $true
        (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash | Should Be $sourceHash
    }
}

Describe 'Image test profiles' -Tag Unit {
    It 'Builds LosslessDefault settings from profile' {
        $settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath 'C:\fake\plugins'
        $settings.Level | Should Be 5
        $settings.OutputMode | Should Be 'Replace'
        $settings.PNGAllowLossy | Should Be $false
        $settings.JPEGAllowLossy | Should Be $false
        $settings.HistoryEnabled | Should Be $false
        $settings.PluginSearchMode | Should Be 'PortableOnly'
    }

    It 'Builds LossyHighQuality settings from profile' {
        $settings = Get-FoImageTestProfile -Name 'LossyHighQuality'
        $settings.Level | Should Be 9
        $settings.PNGAllowLossy | Should Be $true
        $settings.JPEGAllowLossy | Should Be $true
    }
}

Describe 'Invoke-FoImageOptimizationTest' -Tag ImageIntegration {
    BeforeAll {
        if (-not (Test-FoPluginsAvailable)) {
            Set-TestInconclusive 'Plugin binaries not found. Set FO_TEST_PLUGIN_PATH.'
            return
        }
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
    }

    It 'Optimizes jpg-testorig and passes pixel compare' {
        if (-not $script:Settings) { return }

        $result = Invoke-FoImageOptimizationTest -FixtureId 'jpg-testorig' -Settings $script:Settings -CompareMode Pixel

        @('Optimized', 'Unchanged') -contains $result.Optimization.Status | Should Be $true
        if ($result.Optimization.Status -eq 'Optimized') {
            ($result.Optimization.FinalSize -lt $result.Optimization.OriginalSize) | Should Be $true
        }
        $result.Compare.Pass | Should Be $true
        $result.Pass | Should Be $true
        ($result.Decode.Width -gt 0) | Should Be $true
    }
}
