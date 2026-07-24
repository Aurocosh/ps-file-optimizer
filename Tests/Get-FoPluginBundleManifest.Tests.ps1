BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Compare-FoPluginBundleVersion' -Tag Unit {
    It 'Orders semver correctly' {
        (Compare-FoPluginBundleVersion -Left '1.0.0' -Right '1.1.0') | Should -BeLessThan 0
        (Compare-FoPluginBundleVersion -Left '1.1.0' -Right '1.1.0') | Should -Be 0
        (Compare-FoPluginBundleVersion -Left '1.2.0' -Right '1.1.0') | Should -BeGreaterThan 0
    }
}

Describe 'Get-FoInstalledPluginBundleInfo' -Tag Unit {
    It 'Reports missing when no manifest is present' {
        $dir = Join-Path $TestDrive 'plugins-no-manifest'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $dir 'oxipng.exe'), [byte[]](1, 2, 3))
        $info = Get-FoInstalledPluginBundleInfo -PluginPath $dir
        $info.Found | Should -Be $false
        $info.Error | Should -Match 'Manifest not found'
    }

    It 'Reads BundleVersion from fo-plugin-bundle.json' {
        $dir = Join-Path $TestDrive 'plugins-with-manifest'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $payload = [byte[]](1, 2, 3, 4)
        [System.IO.File]::WriteAllBytes((Join-Path $dir 'tool.exe'), $payload)
        $manifest = New-FoPluginBundleManifestObject -PluginDirectory $dir -BundleVersion '1.1.0' -Architecture 64 -SourceBundleVersion '1.0.0'
        Save-FoPluginBundleManifest -Manifest $manifest -Path (Join-Path $dir (Get-FoPluginBundleManifestFileName))

        $info = Get-FoInstalledPluginBundleInfo -PluginPath $dir
        $info.Found | Should -Be $true
        $info.BundleVersion | Should -Be '1.1.0'
        @($info.Manifest.Files).Count | Should -Be 1
    }
}

Describe 'Assert-FoPluginBundleVersionForOptimize' -Tag Unit {
    It 'Fails hard when the portable plugin bundle is not installed' {
        $dir = Join-Path $TestDrive 'empty-plugins'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $settings = @{
            PluginPath                     = $dir
            PluginSearchMode               = 'PortableOnly'
            AcknowledgedPluginBundleMinimum = ''
        }
        { Assert-FoPluginBundleVersionForOptimize -Settings $settings } | Should -Throw '*Plugin bundle is not installed*'
    }

    It 'Allows PathOnly mode without a portable plugin folder' {
        $settings = @{
            PluginPath                     = $null
            PluginSearchMode               = 'PathOnly'
            AcknowledgedPluginBundleMinimum = ''
        }
        { Assert-FoPluginBundleVersionForOptimize -Settings $settings } | Should -Not -Throw
    }

    It 'Throws when binaries exist without a sufficient bundle version' {
        $dir = Join-Path $TestDrive 'legacy-plugins'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $dir 'oxipng.exe'), [byte[]](9, 9, 9))
        $settings = @{ PluginPath = $dir; PluginSearchMode = 'PortableFirst'; AcknowledgedPluginBundleMinimum = '' }
        { Assert-FoPluginBundleVersionForOptimize -Settings $settings } | Should -Throw '*below required minimum*'
    }

    It 'Warns instead of throwing when acknowledgment covers the minimum' {
        $dir = Join-Path $TestDrive 'legacy-acked'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $dir 'oxipng.exe'), [byte[]](8, 8, 8))
        $min = Get-FoMinimumPluginBundleVersion
        $settings = @{ PluginPath = $dir; PluginSearchMode = 'PortableFirst'; AcknowledgedPluginBundleMinimum = $min }
        $warnings = $null
        Assert-FoPluginBundleVersionForOptimize -Settings $settings -WarningVariable warnings -WarningAction SilentlyContinue
        ($warnings | Out-String) | Should -Match 'acknowledgment recorded'
    }

    It 'Re-throws when acknowledgment is for an older minimum' {
        $dir = Join-Path $TestDrive 'legacy-stale-ack'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $dir 'oxipng.exe'), [byte[]](7, 7, 7))
        $settings = @{ PluginPath = $dir; PluginSearchMode = 'PortableFirst'; AcknowledgedPluginBundleMinimum = '1.0.0' }
        { Assert-FoPluginBundleVersionForOptimize -Settings $settings } | Should -Throw '*below required minimum*'
    }

    It 'Passes when installed manifest meets the minimum' {
        $dir = Join-Path $TestDrive 'current-plugins'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $dir 'oxipng.exe'), [byte[]](1, 2, 3))
        $manifest = New-FoPluginBundleManifestObject -PluginDirectory $dir -BundleVersion (Get-FoMinimumPluginBundleVersion) -Architecture 64
        Save-FoPluginBundleManifest -Manifest $manifest -Path (Join-Path $dir (Get-FoPluginBundleManifestFileName))
        $settings = @{ PluginPath = $dir; PluginSearchMode = 'PortableFirst'; AcknowledgedPluginBundleMinimum = '' }
        { Assert-FoPluginBundleVersionForOptimize -Settings $settings } | Should -Not -Throw
    }
}

Describe 'Test-FoPluginBundleManifestFiles' -Tag Unit {
    It 'Detects hash mismatches' {
        $dir = Join-Path $TestDrive 'hash-check'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $dir 'a.exe'), [byte[]](1, 2, 3))
        $manifest = New-FoPluginBundleManifestObject -PluginDirectory $dir -BundleVersion '1.1.0' -Architecture 64
        [System.IO.File]::WriteAllBytes((Join-Path $dir 'a.exe'), [byte[]](4, 5, 6))
        $result = Test-FoPluginBundleManifestFiles -Manifest $manifest -PluginDirectory $dir
        $result.Ok | Should -Be $false
        $result.Mismatched | Should -Contain 'a.exe'
    }
}
