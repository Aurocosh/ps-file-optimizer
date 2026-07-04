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
