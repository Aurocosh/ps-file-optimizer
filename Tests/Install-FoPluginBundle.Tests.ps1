BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Get-FoPluginBundleSettings' -Tag Unit {
    It 'Defaults to aux release x64 zip URL and SHA256' {
        $settings = Get-FoPluginBundleSettings
        $settings.Architecture | Should -Be '64'
        $settings.Url | Should -Match 'ps-file-optimizer-aux'
        $settings.FileName | Should -Be 'fo-plugins-win-x64-1.0.0.zip'
        $settings.Format | Should -Be 'zip'
        $settings.Folder | Should -Be 'Plugins64'
        $settings.Sha256 | Should -Be 'd2889306b31c3bb8b356e2d6de0d5f893f26e2e334812c0e541b9c0fe65a04a0'
    }

    It 'Resolves x86 bundle metadata when Architecture is 32' {
        $settings = Get-FoPluginBundleSettings -Architecture 32
        $settings.Architecture | Should -Be '32'
        $settings.FileName | Should -Be 'fo-plugins-win-x86-1.0.0.zip'
        $settings.Folder | Should -Be 'Plugins32'
        $settings.Format | Should -Be 'zip'
        $settings.Url | Should -Match 'plugins-v1\.0\.0/fo-plugins-win-x86'
        $settings.Sha256 | Should -Be '96bce923ca76a95db522eeea269a031a2b2a648fc0b44b45ef2a1fec202bc5b6'
    }

    It 'ArchiveUrl override uses supplied SHA256' {
        $settings = Get-FoPluginBundleSettings -ArchiveUrl 'https://example.test/bundle.zip' -ArchiveSha256 'abc'
        $settings.Url | Should -Be 'https://example.test/bundle.zip'
        $settings.Format | Should -Be 'zip'
        $settings.Sha256 | Should -Be 'abc'
    }

    It 'Rejects custom ArchiveUrl without SHA256' {
        { Get-FoPluginBundleSettings -ArchiveUrl 'https://example.test/bundle.zip' } |
            Should -Throw '*requires SHA256 verification*'
    }

    It 'Allows custom ArchiveUrl without SHA256 when opt-out is set' {
        $settings = Get-FoPluginBundleSettings -ArchiveUrl 'https://example.test/bundle.zip' -AllowUnverifiedDownload
        $settings.Url | Should -Be 'https://example.test/bundle.zip'
        $settings.Sha256 | Should -BeNullOrEmpty
    }

    It 'Defaults env bundle folder from architecture when folder override is missing' {
        $prevUrl = $env:FO_PLUGIN_BUNDLE_URL
        $prevSha = $env:FO_PLUGIN_BUNDLE_SHA256
        $prevFolder = $env:FO_PLUGIN_BUNDLE_FOLDER
        try {
            $env:FO_PLUGIN_BUNDLE_URL = 'https://example.test/bundle.zip'
            Remove-Item Env:FO_PLUGIN_BUNDLE_SHA256 -ErrorAction SilentlyContinue
            Remove-Item Env:FO_PLUGIN_BUNDLE_FOLDER -ErrorAction SilentlyContinue

            $settings = Get-FoPluginBundleSettings -Architecture 32 -AllowUnverifiedDownload
            $settings.Folder | Should -Be 'Plugins32'
        }
        finally {
            if ($prevUrl) { $env:FO_PLUGIN_BUNDLE_URL = $prevUrl } else { Remove-Item Env:FO_PLUGIN_BUNDLE_URL -ErrorAction SilentlyContinue }
            if ($prevSha) { $env:FO_PLUGIN_BUNDLE_SHA256 = $prevSha } else { Remove-Item Env:FO_PLUGIN_BUNDLE_SHA256 -ErrorAction SilentlyContinue }
            if ($prevFolder) { $env:FO_PLUGIN_BUNDLE_FOLDER = $prevFolder } else { Remove-Item Env:FO_PLUGIN_BUNDLE_FOLDER -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'Resolve-FoPluginBundleArchitecture' -Tag Unit {
    It 'Auto matches process bitness' {
        $expected = if ([Environment]::Is64BitProcess) { '64' } else { '32' }
        Resolve-FoPluginBundleArchitecture -Architecture Auto | Should -Be $expected
    }

    It 'Honors explicit 32 and 64' {
        Resolve-FoPluginBundleArchitecture -Architecture 32 | Should -Be '32'
        Resolve-FoPluginBundleArchitecture -Architecture 64 | Should -Be '64'
    }
}

Describe 'Resolve-FoPluginArchitectureFromPath' -Tag Unit {
    It 'Detects architecture from installed plugin folder name' {
        Resolve-FoPluginArchitectureFromPath -PluginPath 'C:\mod\Plugins32' | Should -Be '32'
        Resolve-FoPluginArchitectureFromPath -PluginPath 'C:\mod\Plugins64' | Should -Be '64'
    }

    It 'Falls back to process bitness for generic plugin paths' {
        $expected = if ([Environment]::Is64BitProcess) { '64' } else { '32' }
        Resolve-FoPluginArchitectureFromPath -PluginPath 'C:\mod\plugins' | Should -Be $expected
    }
}

Describe 'Get-FoGhostscriptExecutableName' -Tag Unit {
    It 'Selects gswin32c for 32-bit plugin architecture' {
        Get-FoGhostscriptExecutableName -Architecture 32 | Should -Be 'gswin32c.exe'
    }

    It 'Selects gswin64c for 64-bit plugin architecture' {
        Get-FoGhostscriptExecutableName -Architecture 64 | Should -Be 'gswin64c.exe'
    }
}

Describe 'Remove-FoInstalledPluginArchitectures' -Tag Unit {
    It 'Removes sibling architecture folders under module root' {
        $root = Join-Path $TestDrive 'mod'
        New-Item -ItemType Directory -Path (Join-Path $root 'Plugins64') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root 'Plugins32') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root 'plugins') -Force | Out-Null

        $removed = Remove-FoInstalledPluginArchitectures -ModuleRoot $root -Scope 64
        $removed.Count | Should -Be 2
        Test-Path -LiteralPath (Join-Path $root 'Plugins64') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $root 'Plugins32') | Should -Be $false
        Test-Path -LiteralPath (Join-Path $root 'plugins') | Should -Be $false
    }

    It 'Remove mode deletes all plugin folders' {
        $root = Join-Path $TestDrive 'mod2'
        New-Item -ItemType Directory -Path (Join-Path $root 'Plugins64') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root 'plugins') -Force | Out-Null

        $removed = Remove-FoInstalledPluginArchitectures -ModuleRoot $root -Scope All
        $removed.Count | Should -Be 2
        Test-Path -LiteralPath (Join-Path $root 'Plugins64') | Should -Be $false
    }
}

Describe 'Test-FoDownloadedFileSha256' -Tag Unit {
    It 'Throws when hash does not match' {
        $file = Join-Path $env:TEMP "FoShaTest_$(Get-Random).bin"
        try {
            Set-Content -LiteralPath $file -Value 'test' -Encoding Ascii
            { Test-FoDownloadedFileSha256 -Path $file -ExpectedSha256 ('0' * 64) } | Should -Throw '*SHA256 mismatch*'
        }
        finally {
            Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Passes when hash matches' {
        $file = Join-Path $env:TEMP "FoShaTest_$(Get-Random).bin"
        try {
            Set-Content -LiteralPath $file -Value 'test' -Encoding Ascii
            $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
            { Test-FoDownloadedFileSha256 -Path $file -ExpectedSha256 $hash } | Should -Not -Throw
        }
        finally {
            Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Get-FoDssimBundleSettings' -Tag Unit {
    It 'Defaults to pinned dssim 3.4.0 GitHub release URL and SHA256' {
        $settings = Get-FoDssimBundleSettings
        $settings.Url | Should -Be 'https://github.com/kornelski/dssim/releases/download/3.4.0/dssim-3.4.0.zip'
        $settings.FileName | Should -Be 'dssim-3.4.0.zip'
        $settings.Version | Should -Be '3.4.0'
        $settings.Sha256 | Should -Be 'c9cb7089a62fd8c2655e778fc576d9f1f453eb3ecfb98bb6914f1ff086ceda4c'
    }

    It 'ArchiveUrl override uses supplied SHA256' {
        $settings = Get-FoDssimBundleSettings -ArchiveUrl 'https://example.test/dssim.zip' -ArchiveSha256 'abc'
        $settings.Url | Should -Be 'https://example.test/dssim.zip'
        $settings.Sha256 | Should -Be 'abc'
    }

    It 'Rejects custom ArchiveUrl without SHA256' {
        { Get-FoDssimBundleSettings -ArchiveUrl 'https://example.test/dssim.zip' } |
            Should -Throw '*requires SHA256 verification*'
    }

    It 'Allows custom ArchiveUrl without SHA256 when opt-out is set' {
        $settings = Get-FoDssimBundleSettings -ArchiveUrl 'https://example.test/dssim.zip' -AllowUnverifiedDownload
        $settings.Url | Should -Be 'https://example.test/dssim.zip'
        $settings.Sha256 | Should -BeNullOrEmpty
    }
}

Describe 'Test-FoDssimCompareAvailable' -Tag Unit {
    It 'Is false when dssim.exe is not installed' {
        $fakeRoot = Join-Path $env:TEMP "FoDssimMissing_$(Get-Random)"
        New-Item -ItemType Directory -Path $fakeRoot -Force | Out-Null
        try {
            Test-FoDssimCompareAvailable -PluginPath $fakeRoot | Should -Be $false
        }
        finally {
            Remove-Item -LiteralPath $fakeRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Assert-FoDssimCompareAvailable' -Tag Unit {
    It 'Throws when dssim.exe is not installed and opt-out is disabled' {
        $fakeRoot = Join-Path $env:TEMP "FoDssimAssert_$(Get-Random)"
        New-Item -ItemType Directory -Path $fakeRoot -Force | Out-Null
        try {
            { Assert-FoDssimCompareAvailable -PluginPath $fakeRoot } | Should -Throw '*DSSIM is required for PNG pixel compare*'
        }
        finally {
            Remove-Item -LiteralPath $fakeRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Does not throw when AllowMissingDssim is set' {
        $fakeRoot = Join-Path $env:TEMP "FoDssimAssert_$(Get-Random)"
        New-Item -ItemType Directory -Path $fakeRoot -Force | Out-Null
        try {
            { Assert-FoDssimCompareAvailable -PluginPath $fakeRoot -AllowMissingDssim } | Should -Not -Throw
        }
        finally {
            Remove-Item -LiteralPath $fakeRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Invoke-FoPluginBundleDownload bundle cache' -Tag Unit {
    It 'Copies from FO_PLUGIN_BUNDLE_CACHE_DIR when archive is cached' {
        $cacheRoot = Join-Path $env:TEMP "FoBundleCacheTest_$(Get-Random)"
        $sha = 'abc123def4567890abc123def4567890abc123def4567890abc123def4567890'
        $cacheDir = Join-Path $cacheRoot $sha
        $fileName = 'test-bundle.zip'
        $cachedFile = Join-Path $cacheDir $fileName
        $destDir = Join-Path $env:TEMP "FoBundleDest_$(Get-Random)"
        $destFile = Join-Path $destDir $fileName
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        Set-Content -LiteralPath $cachedFile -Value 'cached-bundle' -Encoding Ascii -NoNewline
        $prev = $env:FO_PLUGIN_BUNDLE_CACHE_DIR
        $env:FO_PLUGIN_BUNDLE_CACHE_DIR = $cacheRoot
        try {
            Invoke-FoPluginBundleDownload -DestinationFile $destFile -Url 'https://example.test/should-not-fetch.zip' `
                -ExpectedSha256 $sha -ShowProgress:$false
            Get-Content -LiteralPath $destFile -Raw | Should -Be 'cached-bundle'
        }
        finally {
            if ($null -eq $prev) {
                Remove-Item Env:FO_PLUGIN_BUNDLE_CACHE_DIR -ErrorAction SilentlyContinue
            }
            else {
                $env:FO_PLUGIN_BUNDLE_CACHE_DIR = $prev
            }
            Remove-Item -LiteralPath $cacheRoot -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $destDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Plugin bundle extract safety' -Tag Unit {
    BeforeAll {
        . (Join-Path (Get-FoTestModuleRoot) 'Private\Install-FoPluginBundle.ps1')
    }

    It 'Rejects zip archives with path traversal entries' {
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zipPath = Join-Path $TestDrive 'evil.zip'
        $extractRoot = Join-Path $TestDrive 'extract-safe'
        New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

        $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $entry = $zip.CreateEntry('..\evil.txt')
            $writer = New-Object System.IO.StreamWriter($entry.Open())
            $writer.Write('pwnd')
            $writer.Dispose()
        }
        finally {
            $zip.Dispose()
        }

        { Assert-FoPluginBundleArchiveSafe -ArchivePath $zipPath -ExtractRoot $extractRoot } |
            Should -Throw '*Unsafe zip entry path*'
    }
}

Describe 'Staged plugin install' -Tag Unit {
    BeforeAll {
        . (Join-Path (Get-FoTestModuleRoot) 'Private\Install-FoPluginBundle.ps1')
    }

    It 'Leaves destination unchanged when staging copy fails' {
        $dest = Join-Path $TestDrive 'plugins-dest'
        $stage = Join-Path $TestDrive 'plugins-stage'
        $source = Join-Path $TestDrive 'bundle-src'
        New-Item -ItemType Directory -Path $dest, $source -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dest 'magick.exe') -Value 'keep-me' -NoNewline
        Copy-Item -LiteralPath $dest -Destination $stage -Recurse -Force
        Set-Content -LiteralPath (Join-Path $source 'oxipng.exe') -Value 'new-tool' -NoNewline

        $realCopy = Get-Command Copy-Item -Module Microsoft.PowerShell.Management
        Mock Copy-Item {
            param($LiteralPath, $Destination, $Force)
            if ($LiteralPath -like '*oxipng.exe') {
                throw 'Simulated staging copy failure'
            }
            & $realCopy @PSBoundParameters
        }

        { Copy-FoPluginFilesFromBundle -SourcePluginDir $source -DestinationPluginDir $stage -FileNames @('oxipng.exe') -Force } |
            Should -Throw 'Simulated staging copy failure'
        (Get-Content -LiteralPath (Join-Path $dest 'magick.exe') -Raw) | Should -Be 'keep-me'
    }

    It 'Restores destination when publish fails after staging' {
        $dest = Join-Path $TestDrive 'plugins-publish'
        $stage = Join-Path $TestDrive 'plugins-publish-stage'
        New-Item -ItemType Directory -Path $dest, $stage -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dest 'existing.exe') -Value 'original' -NoNewline
        Set-Content -LiteralPath (Join-Path $stage 'existing.exe') -Value 'staged' -NoNewline

        $realMove = Get-Command Move-Item -Module Microsoft.PowerShell.Management
        $stageFull = [System.IO.Path]::GetFullPath($stage)
        Mock Move-Item {
            param($LiteralPath, $Destination, $Force)
            if ([System.IO.Path]::GetFullPath($LiteralPath) -eq $stageFull) {
                throw 'Simulated publish failure'
            }
            & $realMove @PSBoundParameters
        }

        { Publish-FoPluginInstallStage -StageDir $stage -DestinationPath $dest } | Should -Throw 'Simulated publish failure'
        (Get-Content -LiteralPath (Join-Path $dest 'existing.exe') -Raw) | Should -Be 'original'
    }
}

Describe 'Clear-FoPluginResolveCache' -Tag Unit {
    BeforeAll {
        Import-Module (Join-Path (Get-FoTestModuleRoot) 'FileOptimizer.psd1') -Force
    }

    It 'Clears cached plugin resolution entries' {
        InModuleScope FileOptimizer {
            $script:FoPluginResolveCache['unit-test-key'] = @{ Found = $true }
            Clear-FoPluginResolveCache
            $script:FoPluginResolveCache.ContainsKey('unit-test-key') | Should -Be $false
        }
    }
}
