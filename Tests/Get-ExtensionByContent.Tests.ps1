BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Get-ExtensionByContent' -Tag Unit {
    It 'Does not throw on a 4-byte file' {
        $path = Join-Path $TestDrive 'short.bin'
        [System.IO.File]::WriteAllBytes($path, [byte[]](0x00, 0x00, 0x00, 0x00))
        { Get-ExtensionByContent -Path $path -Extension '.bin' } | Should -Not -Throw
        Get-ExtensionByContent -Path $path -Extension '.bin' | Should -Be ''
    }

    It 'Detects PNG by content when extension is unknown' {
        $fixture = Join-Path (Get-FoTestModuleRoot) 'Tests\Fixtures\Images\pngsuite\basn0g01.png'
        $path = Join-Path $TestDrive 'misnamed.bin'
        Copy-Item -LiteralPath $fixture -Destination $path -Force
        Get-ExtensionByContent -Path $path -Extension '.bin' | Should -Be '.png'
        Get-FoPipelineGroupsForFile -Path $path | Should -Contain 'PNG'
    }

    It 'Detects JPEG by content using the C++ signature' {
        $fixture = Join-Path (Get-FoTestModuleRoot) 'Tests\Fixtures\Images\jpeg-conformance\valid\grayscale_square.jpg'
        $path = Join-Path $TestDrive 'misnamed.dat'
        Copy-Item -LiteralPath $fixture -Destination $path -Force
        Get-ExtensionByContent -Path $path -Extension '.dat' | Should -Be '.jpg'
    }

    It 'Detects ZIP only for PK\x03\x04 archives' {
        $zipLike = Join-Path $TestDrive 'pk-only.bin'
        [System.IO.File]::WriteAllBytes($zipLike, [byte[]](0x50, 0x4B, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00))
        Get-ExtensionByContent -Path $zipLike -Extension '.bin' | Should -Be ''

        $zipPath = Join-Path $TestDrive 'real.zip'
        [System.IO.File]::WriteAllBytes($zipPath, [byte[]](0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00))
        Get-ExtensionByContent -Path $zipPath -Extension '.bin' | Should -Be '.zip'
    }

    It 'Returns .dll for MZ executables to match FileOptimizer' {
        $path = Join-Path $TestDrive 'misnamed.bin'
        [System.IO.File]::WriteAllBytes($path, [byte[]](0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00))
        Get-ExtensionByContent -Path $path -Extension '.bin' | Should -Be '.dll'
        Get-FoPipelineGroupsForFile -Path $path | Should -Contain 'DLL'
    }

    It 'Returns .sqlite for SQLite databases' {
        $path = Join-Path $TestDrive 'misnamed.bin'
        $bytes = [System.Text.Encoding]::ASCII.GetBytes('SQLite format 3')
        $padded = New-Object byte[] 32
        [Array]::Copy($bytes, $padded, $bytes.Length)
        [System.IO.File]::WriteAllBytes($path, $padded)
        Get-ExtensionByContent -Path $path -Extension '.bin' | Should -Be '.sqlite'
        Get-FoPipelineGroupsForFile -Path $path | Should -Contain 'SQLite'
    }

    It 'Uses filename extension for multi-group routing when content is inconclusive' {
        $path = Join-Path $TestDrive 'multi.db'
        Set-Content -LiteralPath $path -Value 'placeholder' -NoNewline
        Get-FoPipelineGroupsForFile -Path $path | Should -Be @('OLE', 'SQLite')
    }
}

Describe 'Format-FoProcessArgument' -Tag Unit {
    It 'Quotes paths with spaces and embedded double quotes' {
        Format-FoProcessArgument -Value 'plain.exe' | Should -Be 'plain.exe'
        Format-FoProcessArgument -Value 'has space' | Should -Match '^".*"$'
        Format-FoProcessArgument -Value 'say"hello' | Should -Be '"say\"hello"'
    }
}
