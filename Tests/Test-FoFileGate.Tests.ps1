BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Test-FoIsAPNG' -Tag Unit {
    It 'Detects valid APNG fixture' {
        $path = Join-Path (Get-FoImageTestFixtureRoot) 'apng-conformance\valid\3frame_rgb.png'
        $ctx = New-FoFileContext -InputFile $path -Settings (Get-FoConfig)
        $ctx.IsAPNG | Should -Be $true
    }

    It 'Returns false for static PNG without animation chunks' {
        $path = Join-Path (Get-FoImageTestFixtureRoot) 'pngsuite\basn2c08.png'
        $ctx = New-FoFileContext -InputFile $path -Settings (Get-FoConfig)
        $ctx.IsAPNG | Should -Be $false
    }

    It 'Returns false for corrupt tiny file' {
        $path = Join-Path $TestDrive 'tiny.png'
        Set-Content -LiteralPath $path -Value 'not a png' -NoNewline
        $ctx = New-FoFileContext -InputFile $path -Settings (Get-FoConfig)
        $ctx.IsAPNG | Should -Be $false
    }

    It 'Returns false for PNG signature only' {
        $path = Join-Path $TestDrive 'sig-only.png'
        [System.IO.File]::WriteAllBytes($path, [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A))
        $ctx = New-FoFileContext -InputFile $path -Settings (Get-FoConfig)
        $ctx.IsAPNG | Should -Be $false
    }
}

Describe 'PNG pipeline APNG routing' -Tag Unit {
    It 'Selects APNG-safe step subset for animated PNG' {
        $path = Join-Path (Get-FoImageTestFixtureRoot) 'apng-conformance\valid\3frame_rgb.png'
        $ctx = New-FoFileContext -InputFile $path -Settings (Get-FoConfig)
        $ctx.IsAPNG | Should -Be $true

        $steps = Get-FoPipeline -GroupName PNG -Context $ctx
        $names = $steps | ForEach-Object { $_.Name }

        ($names | Where-Object { $_ -like 'apngopt*' }).Count | Should -Be 1
        ($names | Where-Object { $_ -like 'pngquant*' }).Count | Should -Be 0
        ($names | Where-Object { $_ -like 'Leanify*' }).Count | Should -Be 0
        ($names | Where-Object { $_ -like 'pngwolf*' }).Count | Should -Be 0
    }

    It 'Excludes APNG-only steps for static PNG' {
        $path = Join-Path (Get-FoImageTestFixtureRoot) 'pngsuite\basn2c08.png'
        $ctx = New-FoFileContext -InputFile $path -Settings (Get-FoConfig)
        $ctx.IsAPNG | Should -Be $false

        $steps = Get-FoPipeline -GroupName PNG -Context $ctx
        ($steps.Count -gt 0) | Should -Be $true
        @($steps | Where-Object { $_.Name -like 'apngopt*' }).Count | Should -Be 0
    }
}

Describe 'Context detection stubs' -Tag Unit {
    It 'Detects Inno Setup EXE SFX' {
        $path = Join-Path $TestDrive 'inno-sfx.exe'
        $bytes = [System.Text.Encoding]::ASCII.GetBytes("MZ`0`0Inno Setup installer payload")
        [System.IO.File]::WriteAllBytes($path, $bytes)
        $ctx = New-FoFileContext -InputFile $path -Settings (Get-FoConfig)
        $ctx.IsEXESFX | Should -Be $true
        $ctx.IsZipSFX | Should -Be $true
    }

    It 'Does not flag standard ZIP archives as EXE SFX' {
        $path = Join-Path (Get-FoImageTestFixtureRoot) 'pngsuite\basn2c08.png'
        $ctx = New-FoFileContext -InputFile $path -Settings (Get-FoConfig)
        $ctx.IsEXESFX | Should -Be $false
    }

    It 'Detects layered PDF via OCG marker' {
        $path = Join-Path $TestDrive 'layered.pdf'
        $text = "%PDF-1.4`n<< /Type /OCG /Name /Layer1 >>"
        Set-Content -LiteralPath $path -Value $text -NoNewline
        $ctx = New-FoFileContext -InputFile $path -Settings (Get-FoConfig)
        $ctx.IsPDFLayered | Should -Be $true
    }

    It 'Detects progressive CMYK JPEG' {
        $path = Join-Path $TestDrive 'cmyk.jpg'
        $buf = New-Object byte[] 32
        $buf[0] = 0xFF; $buf[1] = 0xD8
        $buf[2] = 0xFF; $buf[3] = 0xC0
        $buf[10] = 0xFF; $buf[11] = 0xC2
        $buf[19] = 4
        [System.IO.File]::WriteAllBytes($path, $buf)
        $ctx = New-FoFileContext -InputFile $path -Settings (Get-FoConfig)
        $ctx.IsJPEGCMYK | Should -Be $true
    }
}

Describe 'Pipeline routing for context flags' -Tag Unit {
    It 'Skips EXE SFX-sensitive steps for Inno Setup payloads' {
        $path = Join-Path $TestDrive 'route-inno.exe'
        $bytes = [System.Text.Encoding]::ASCII.GetBytes("MZ`0`0Inno Setup")
        [System.IO.File]::WriteAllBytes($path, $bytes)
        $ctx = New-FoFileContext -InputFile $path -Settings (Get-FoConfig)
        $active = foreach ($step in (Get-FoPipeline -GroupName EXE -Context $ctx)) {
            if ($step.Gate) { if (& $step.Gate $ctx) { $step } } else { $step }
        }
        @($active | Where-Object { $_.Name -like 'UPX*' }).Count | Should -Be 0
        @($active | Where-Object { $_.Name -like 'PETrim*' }).Count | Should -Be 0
    }

    It 'Omits jhead for CMYK JPEG' {
        $path = Join-Path $TestDrive 'route-cmyk.jpg'
        $buf = New-Object byte[] 32
        $buf[0] = 0xFF; $buf[1] = 0xD8
        $buf[2] = 0xFF; $buf[3] = 0xC0
        $buf[10] = 0xFF; $buf[11] = 0xC2
        $buf[19] = 4
        [System.IO.File]::WriteAllBytes($path, $buf)
        $ctx = New-FoFileContext -InputFile $path -Settings (Get-FoConfig)
        $steps = Get-FoPipeline -GroupName JPEG -Context $ctx
        @($steps | Where-Object { $_.Name -like 'jhead*' }).Count | Should -Be 0
    }

    It 'Skips layered PDF steps when PDFSkipLayered is enabled' {
        $path = Join-Path $TestDrive 'route-layered.pdf'
        Set-Content -LiteralPath $path -Value '%PDF-1.4 << /Type /OCG /Name /L >>' -NoNewline
        $settings = Get-FoConfig
        $settings.PDFSkipLayered = $true
        $settings.PDFProfile = 'ebook'
        $ctx = New-FoFileContext -InputFile $path -Settings $settings
        $active = foreach ($step in (Get-FoPipeline -GroupName PDF -Context $ctx)) {
            if ($step.Gate) { if (& $step.Gate $ctx) { $step } } else { $step }
        }
        $active.Count | Should -Be 0
    }
}
