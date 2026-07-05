BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Get-FoPluginBundleSettings' -Tag Unit {
    It 'Defaults to aux release 7z URL and SHA256' {
        $settings = Get-FoPluginBundleSettings
        $settings.Url | Should -Match 'ps-file-optimizer-aux'
        $settings.FileName | Should -Be 'fo-plugins-win-x64-1.0.0.7z'
        $settings.Format | Should -Be '7z'
        $settings.Sha256 | Should -Match '^[a-f0-9]{64}$'
    }

    It 'ArchiveUrl override uses supplied SHA256' {
        $settings = Get-FoPluginBundleSettings -ArchiveUrl 'https://example.test/bundle.7z' -ArchiveSha256 'abc'
        $settings.Url | Should -Be 'https://example.test/bundle.7z'
        $settings.Sha256 | Should -Be 'abc'
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
