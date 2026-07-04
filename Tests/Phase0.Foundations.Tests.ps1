$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

. "$PSScriptRoot\TestHelpers.ps1"

Describe 'Image test decisions manifest' -Tag Unit {
    It 'Loads ImageTestDecisions.psd1 with expected keys' {
        $d = Get-FoImageTestDecisions
        $d.JpegPrimaryMode | Should Be 'PixelAE'
        $d.JpegSSIMFallbackMaximum | Should Be 0
        $d.IcoCompareScope | Should Be 'LargestEmbedded'
        $d.AvifDefaultSSIMDissimilarityMaximum | Should Be 0
        $d.FixtureBudgetBytes | Should Be 512000
        $d.Tags.ImageIntegration | Should Not BeNullOrEmpty
    }
}

Describe 'Get-FoTestPluginPath' -Tag Unit {
    It 'Prefers FO_TEST_PLUGIN_PATH when set' {
        $expected = Join-Path $env:TEMP "FoPluginPathTest_$(Get-Random)"
        New-Item -ItemType Directory -Path $expected -Force | Out-Null
        $previous = $env:FO_TEST_PLUGIN_PATH
        $env:FO_TEST_PLUGIN_PATH = $expected
        try {
            Get-FoTestPluginPath | Should Be ([System.IO.Path]::GetFullPath($expected))
        }
        finally {
            if ($null -eq $previous) {
                Remove-Item Env:FO_TEST_PLUGIN_PATH -ErrorAction SilentlyContinue
            }
            else {
                $env:FO_TEST_PLUGIN_PATH = $previous
            }
            Remove-Item -LiteralPath $expected -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Returns null when FO_TEST_PLUGIN_PATH points to a missing directory' {
        $previous = $env:FO_TEST_PLUGIN_PATH
        $env:FO_TEST_PLUGIN_PATH = 'C:\nonexistent_fo_plugins_12345'
        try {
            Get-FoTestPluginPath | Should Be $null
        }
        finally {
            if ($null -eq $previous) {
                Remove-Item Env:FO_TEST_PLUGIN_PATH -ErrorAction SilentlyContinue
            }
            else {
                $env:FO_TEST_PLUGIN_PATH = $previous
            }
        }
    }
}

Describe 'Test-FoPluginsAvailable' -Tag Unit {
    It 'Is false when no plugin directory is available' {
        $previous = $env:FO_TEST_PLUGIN_PATH
        $env:FO_TEST_PLUGIN_PATH = 'C:\nonexistent_fo_plugins_12345'
        try {
            Test-FoPluginsAvailable | Should Be $false
        }
        finally {
            if ($null -eq $previous) {
                Remove-Item Env:FO_TEST_PLUGIN_PATH -ErrorAction SilentlyContinue
            }
            else {
                $env:FO_TEST_PLUGIN_PATH = $previous
            }
        }
    }

    It 'Finds magick.exe when plugins are present' {
        $pluginPath = Get-FoTestPluginPath
        if (-not $pluginPath) {
            Set-TestInconclusive 'No plugin directory discovered'
            return
        }
        if (-not (Test-FoPluginsAvailable)) {
            Set-TestInconclusive "magick.exe not found under $pluginPath"
            return
        }
        Test-FoPluginsAvailable | Should Be $true
    }
}
