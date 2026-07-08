BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Get-FoTargetFiles' -Tag Unit {
    BeforeAll {
        $moduleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        . (Join-Path $moduleRoot 'Private\Get-FoTargetFiles.ps1')
    }

    It 'Expands quoted wildcard paths to matching files' {
        $dir = Join-Path $TestDrive 'wildcard'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $pngA = Join-Path $dir 'a.png'
        $pngB = Join-Path $dir 'b.png'
        $txt = Join-Path $dir 'c.txt'
        Set-Content -LiteralPath $pngA -Value 'png-a' -NoNewline
        Set-Content -LiteralPath $pngB -Value 'png-b' -NoNewline
        Set-Content -LiteralPath $txt -Value 'txt' -NoNewline

        $glob = Join-Path $dir '*.png'
        $files = @(Get-FoTargetFiles -Path $glob)

        $files.Count | Should -Be 2
        $files | Should -Contain ([System.IO.Path]::GetFullPath($pngA))
        $files | Should -Contain ([System.IO.Path]::GetFullPath($pngB))
    }

    It 'Warns when a wildcard matches no files' {
        $dir = Join-Path $TestDrive 'wildcard-empty'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $glob = Join-Path $dir '*.png'

        $files = @(Get-FoTargetFiles -Path $glob)

        $files.Count | Should -Be 0
    }

    It 'Still enumerates directories without wildcards' {
        $dir = Join-Path $TestDrive 'plain-dir'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $file = Join-Path $dir 'only.txt'
        Set-Content -LiteralPath $file -Value 'only' -NoNewline

        $files = @(Get-FoTargetFiles -Path $dir)

        $files.Count | Should -Be 1
        $files[0] | Should -Be ([System.IO.Path]::GetFullPath($file))
    }
}

Describe 'Optimize-FoFile wildcard paths' -Tag Unit {
    It 'Optimizes each file matched by a quoted wildcard path' {
        $dir = Join-Path $TestDrive 'optimize-wild'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $pngA = Join-Path $dir 'a.png'
        $pngB = Join-Path $dir 'b.png'
        New-FoTestPng -Path $pngA
        New-FoTestPng -Path $pngB

        $glob = Join-Path $dir '*.png'
        $results = @(Optimize-FoFile -Path $glob -WhatIf -PluginPath 'C:\nonexistent' -PluginSearchMode PortableOnly)

        $results.Count | Should -Be 2
        $results.Status | Should -Not -Contain 'Error'
    }
}
