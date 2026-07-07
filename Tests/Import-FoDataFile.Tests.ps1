BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Import-FoDataFile' -Tag Unit {
    It 'Loads committed module data files unchanged' {
        $decisionsPath = Join-Path $PSScriptRoot 'ImageTestDecisions.psd1'
        $data = Import-FoDataFile -Path $decisionsPath
        $data.JpegSSIMFallbackMaximum | Should -Be 0
        $data.PngDssimDissimilarityMaximum | Should -Be 0
    }

    It 'Rejects malicious PSD1 content without executing commands' {
        $marker = Join-Path $TestDrive 'psd1-safe-marker.txt'
        $psd1 = Join-Path $TestDrive 'evil.psd1'
        $malicious = @"
@{
    Key = 1
}
Remove-Item -LiteralPath '$marker' -Force -ErrorAction SilentlyContinue
"@
        Set-Content -LiteralPath $psd1 -Value $malicious -Encoding UTF8
        New-Item -ItemType File -Path $marker -Force | Out-Null

        { Import-FoDataFile -Path $psd1 } | Should -Throw '*executable content*'
        Test-Path -LiteralPath $marker | Should -Be $true
    }

    It 'Rejects subexpression injection in PSD1 strings' {
        $marker = Join-Path $TestDrive 'psd1-subexpr-marker.txt'
        $psd1 = Join-Path $TestDrive 'evil-subexpr.psd1'
        $malicious = @"
@{
    Key = "`$(New-Item -ItemType File -Path '$marker' -Force | Out-Null)"
}
"@
        Set-Content -LiteralPath $psd1 -Value $malicious -Encoding UTF8

        { Import-FoDataFile -Path $psd1 } | Should -Throw '*executable content*'
        Test-Path -LiteralPath $marker | Should -Be $false
    }
}
