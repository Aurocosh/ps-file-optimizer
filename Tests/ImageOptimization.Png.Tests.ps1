BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'PNG lossless optimization (Tier A fixtures)' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'png-corpus'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Optimizes png-basn2c08 (RGB) with valid output' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'png-basn2c08' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir -SkipCompare

        (Test-FoImageOptimizationResult -Result $result -RequireSizeReduction) | Should -Be $true
    }

    It 'Optimizes png-basn6a08 (RGBA) with valid output' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'png-basn6a08' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir -SkipCompare

        (Test-FoImageOptimizationResult -Result $result -RequireSizeReduction) | Should -Be $true
    }
}

Describe 'PNG lossless optimization (pixel identity)' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'png-generated'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Preserves pixels on a magick-generated PNG after optimization' {
        $fixture = Join-Path $script:WorkDir 'generated-64x64.png'
        New-FoTestPng -Path $fixture -Width 64 -Height 64

        $diffDir = Join-Path $script:WorkDir 'diffs'
        New-Item -ItemType Directory -Path $diffDir -Force | Out-Null
        $diffPath = Join-Path $diffDir 'generated-64x64-diff.png'

        $result = Invoke-FoImageOptimizationTest -FixturePath $fixture -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir -DiffOutputPath $diffPath

        (Test-FoImageOptimizationResult -Result $result -RequireCompare) | Should -Be $true

        if (-not $result.Compare.Pass -and (Test-Path -LiteralPath $diffPath)) {
            Write-Warning "Compare diff written to $diffPath"
        }
    }
}

Describe 'PNG lossless optimization (level 9)' -Tag ImageIntegration, Slow -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:Settings['Level'] = 9
        $script:WorkDir = Join-Path $TestDrive 'png-level9'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'Optimizes png-basn2c08 at level 9 with valid output' {
        $result = Invoke-FoImageOptimizationTest -FixtureId 'png-basn2c08' -Settings $script:Settings `
            -CompareMode Pixel -WorkDirectory $script:WorkDir -SkipCompare

        (Test-FoImageOptimizationResult -Result $result -RequireSizeReduction) | Should -Be $true
        $script:Settings.Level | Should -Be 9
    }
}
