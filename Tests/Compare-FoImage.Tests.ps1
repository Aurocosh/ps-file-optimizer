BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Compare-FoImage' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:WorkDir = Join-Path $env:TEMP "FoCompareTests_$(Get-Random)"
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    AfterAll {
        if ($script:WorkDir -and (Test-Path -LiteralPath $script:WorkDir)) {
            Remove-Item -LiteralPath $script:WorkDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Reports identical PNG files as a pass in Pixel mode' -Skip:(-not (Test-FoDssimCompareAvailable -PluginPath $script:PluginPath)) {
        $original = Join-Path $script:WorkDir 'identical-source.png'
        $copy = Join-Path $script:WorkDir 'identical-copy.png'
        New-FoTestPng -Path $original -Width 32 -Height 32
        Copy-Item -LiteralPath $original -Destination $copy

        $result = Compare-FoImage -Before $original -After $copy -Mode Pixel -PluginPath $script:PluginPath

        $result.Pass | Should -Be $true
        $result.MetricValue | Should -Be 0
        $result.Width | Should -Be 32
        $result.Height | Should -Be 32
        $result.CompareTool | Should -Be 'Dssim'
    }

    It 'Throws when dssim is missing for PNG pixel compare' -Skip:(Test-FoDssimCompareAvailable -PluginPath $script:PluginPath) {
        $original = Join-Path $script:WorkDir 'dssim-required-source.png'
        $copy = Join-Path $script:WorkDir 'dssim-required-copy.png'
        New-FoTestPng -Path $original -Width 8 -Height 8
        Copy-Item -LiteralPath $original -Destination $copy

        { Compare-FoImage -Before $original -After $copy -Mode Pixel -PluginPath $script:PluginPath } |
            Should -Throw '*DSSIM is required for PNG pixel compare*'
    }

    It 'Falls back to magick AE when dssim is missing and AllowMissingDssim is set' -Skip:(Test-FoDssimCompareAvailable -PluginPath $script:PluginPath) {
        $original = Join-Path $script:WorkDir 'allow-missing-source.png'
        $copy = Join-Path $script:WorkDir 'allow-missing-copy.png'
        New-FoTestPng -Path $original -Width 16 -Height 16
        Copy-Item -LiteralPath $original -Destination $copy

        $result = Compare-FoImage -Before $original -After $copy -Mode Pixel -PluginPath $script:PluginPath `
            -AllowMissingDssim

        $result.Pass | Should -Be $true
        $result.MetricValue | Should -Be 0
    }

    It 'Reports different PNG files as a fail in Pixel mode' -Skip:(-not (Test-FoDssimCompareAvailable -PluginPath $script:PluginPath)) {
        $before = Join-Path $script:WorkDir 'before.png'
        $after = Join-Path $script:WorkDir 'after.png'
        $diff = Join-Path $script:WorkDir 'diff.png'
        New-FoTestPng -Path $before -Width 32 -Height 32
        Copy-Item -LiteralPath $before -Destination $after

        $magick = (Resolve-FoPluginExecutable -Name 'magick.exe' -SearchMode PortableOnly -PluginPath $script:PluginPath).Path
        $draw = Invoke-FoMagickCli -MagickExe $magick -ArgumentList @(
            $after
            '-fill', 'red'
            '-draw', 'point 5,5'
            $after
        ) -WorkingDirectory (Split-Path -Parent $magick)
        $draw.ExitCode | Should -Be 0

        $result = Compare-FoImage -Before $before -After $after -Mode Pixel -PluginPath $script:PluginPath -DiffOutputPath $diff

        $result.Pass | Should -Be $false
        ($result.MetricValue -gt 0) | Should -Be $true
        if ($null -ne $result.DiffPath) {
            (Test-Path -LiteralPath $result.DiffPath) | Should -Be $true
        }
    }

    It 'Reports identical PNG files with zero SSIM dissimilarity' {
        $original = Join-Path $script:WorkDir 'ssim-source.png'
        $copy = Join-Path $script:WorkDir 'ssim-copy.png'
        New-FoTestPng -Path $original -Width 16 -Height 16
        Copy-Item -LiteralPath $original -Destination $copy

        $result = Compare-FoImage -Before $original -After $copy -Mode SSIM -PluginPath $script:PluginPath

        $result.Pass | Should -Be $true
        $result.MetricValue | Should -Be 0
    }

    It 'Reports different PNG files as SSIM dissimilarity above zero' {
        $before = Join-Path $script:WorkDir 'ssim-before.png'
        $after = Join-Path $script:WorkDir 'ssim-after.png'
        New-FoTestPng -Path $before -Width 16 -Height 16
        Copy-Item -LiteralPath $before -Destination $after

        $magick = (Resolve-FoPluginExecutable -Name 'magick.exe' -SearchMode PortableOnly -PluginPath $script:PluginPath).Path
        $null = Invoke-FoMagickCli -MagickExe $magick -ArgumentList @(
            $after, '-fill', 'red', '-draw', 'point 5,5', $after
        ) -WorkingDirectory (Split-Path -Parent $magick)

        $result = Compare-FoImage -Before $before -After $after -Mode SSIM -PluginPath $script:PluginPath

        $result.Pass | Should -Be $false
        ($result.MetricValue -gt 0) | Should -Be $true
    }

    It 'Get-FoImageInfo returns dimensions and format' {
        $path = Join-Path $script:WorkDir 'info.png'
        New-FoTestPng -Path $path -Width 24 -Height 18

        $info = Get-FoImageInfo -Path $path -PluginPath $script:PluginPath

        $info.Width | Should -Be 24
        $info.Height | Should -Be 18
        $info.Format.ToUpperInvariant() | Should -Match 'PNG'
    }
}
