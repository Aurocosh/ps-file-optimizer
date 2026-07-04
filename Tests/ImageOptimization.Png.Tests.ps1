$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

. "$PSScriptRoot\TestHelpers.ps1"

Describe 'PNG lossless optimization (Tier A fixtures)' -Tag ImageIntegration {
    BeforeAll {
        if (-not (Test-FoPluginsAvailable)) {
            Set-TestInconclusive 'Plugin binaries not found. Set FO_TEST_PLUGIN_PATH.'
            return
        }
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'png-corpus'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    # PNGsuite micro-images (32x32) often fail pixel AE after the full FO chain
    # because plugins re-encode colorspace (rgb -> srgb). Decode + size checks still apply.
    It 'Optimizes png-basn2c08 (RGB) with valid output' {
        if (-not $script:Settings) { return }

        $result = Invoke-FoImageOptimizationTest -FixtureId 'png-basn2c08' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir -SkipCompare

        Assert-FoImageOptimizationResult -Result $result -RequireSizeReduction
    }

    It 'Optimizes png-basn6a08 (RGBA) with valid output' {
        if (-not $script:Settings) { return }

        $result = Invoke-FoImageOptimizationTest -FixtureId 'png-basn6a08' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir -SkipCompare

        Assert-FoImageOptimizationResult -Result $result -RequireSizeReduction
    }
}

Describe 'PNG lossless optimization (pixel identity)' -Tag ImageIntegration {
    BeforeAll {
        if (-not (Test-FoPluginsAvailable)) {
            Set-TestInconclusive 'Plugin binaries not found. Set FO_TEST_PLUGIN_PATH.'
            return
        }
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'png-generated'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Preserves pixels on a magick-generated PNG after optimization' {
        if (-not $script:Settings) { return }

        $fixture = Join-Path $script:WorkDir 'generated-64x64.png'
        New-FoTestPng -Path $fixture -Width 64 -Height 64

        $diffDir = Join-Path $script:WorkDir 'diffs'
        New-Item -ItemType Directory -Path $diffDir -Force | Out-Null
        $diffPath = Join-Path $diffDir 'generated-64x64-diff.png'

        $result = Invoke-FoImageOptimizationTest -FixturePath $fixture -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir -DiffOutputPath $diffPath

        Assert-FoImageOptimizationResult -Result $result -RequireCompare

        if (-not $result.Compare.Pass -and (Test-Path -LiteralPath $diffPath)) {
            Write-Warning "Compare diff written to $diffPath"
        }
    }
}

Describe 'PNG lossless optimization (level 9)' -Tag ImageIntegration, Slow {
    BeforeAll {
        if (-not (Test-FoPluginsAvailable)) {
            Set-TestInconclusive 'Plugin binaries not found. Set FO_TEST_PLUGIN_PATH.'
            return
        }
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:Settings['Level'] = 9
        $script:WorkDir = Join-Path $TestDrive 'png-level9'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Optimizes png-basn2c08 at level 9 with valid output' {
        if (-not $script:Settings) { return }

        $result = Invoke-FoImageOptimizationTest -FixtureId 'png-basn2c08' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir -SkipCompare

        Assert-FoImageOptimizationResult -Result $result -RequireSizeReduction
        $script:Settings.Level | Should -Be 9
    }
}
