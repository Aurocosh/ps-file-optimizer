BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Image test decisions manifest' -Tag Unit {
    It 'Loads ImageTestDecisions.psd1 with compare thresholds' {
        $d = Get-FoImageTestDecisions
        $d.JpegSSIMFallbackMaximum | Should -Be 0
        $d.AvifDefaultSSIMDissimilarityMaximum | Should -Be 0.005
        $d.PngDssimDissimilarityMaximum | Should -Be 0
    }
}

Describe 'Get-FoTestPluginPath' -Tag Unit {
    It 'Prefers FO_TEST_PLUGIN_PATH when set' {
        $expected = Join-Path $env:TEMP "FoPluginPathTest_$(Get-Random)"
        New-Item -ItemType Directory -Path $expected -Force | Out-Null
        $previous = $env:FO_TEST_PLUGIN_PATH
        $env:FO_TEST_PLUGIN_PATH = $expected
        try {
            Get-FoTestPluginPath | Should -Be ([System.IO.Path]::GetFullPath($expected))
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
            Get-FoTestPluginPath | Should -Be $null
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

    It 'Resolves FO_TEST_PLUGIN_PATH relative to module root when not found under CWD' {
        $moduleRoot = Get-FoTestModuleRoot
        $plugins64 = Join-Path $moduleRoot 'Plugins64'
        if (-not (Test-Path -LiteralPath (Join-Path $plugins64 'magick.exe'))) {
            Set-ItResult -Skipped -Because 'Plugins64/magick.exe is not installed'
            return
        }

        $previous = $env:FO_TEST_PLUGIN_PATH
        $previousLocation = Get-Location
        $env:FO_TEST_PLUGIN_PATH = 'Plugins64'
        try {
            Set-Location (Join-Path $moduleRoot 'Tests')
            Get-FoTestPluginPath | Should -Be ([System.IO.Path]::GetFullPath($plugins64))
        }
        finally {
            Set-Location $previousLocation
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
            Test-FoPluginsAvailable | Should -Be $false
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
        $pluginDir = Join-Path $TestDrive 'plugins'
        New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $pluginDir 'magick.exe') -Force | Out-Null

        $previous = $env:FO_TEST_PLUGIN_PATH
        $env:FO_TEST_PLUGIN_PATH = $pluginDir
        try {
            Test-FoPluginsAvailable | Should -Be $true
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
