BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Invoke-FoPlugin in-place rollback' -Tag Unit {
    It 'Restores work file when in-place step increases size' {
        $workDir = Join-Path $TestDrive 'inplace-grow'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.dat'
        $original = 'A' * 100
        Set-Content -LiteralPath $workFile -Value $original -NoNewline

        $sizeBefore = (Get-Item -LiteralPath $workFile).Length
        $step = [PSCustomObject]@{
            Name = 'grow-inplace'; Executable = 'cmd.exe'
            Arguments = '/c echo X>>"%INPUTFILE%"'; Handler = $null; Mode = 'InPlace'; Gate = $null
        }
        $settings = Get-FoConfig

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly

        $result.Accepted | Should -Be $false
        (Get-Item -LiteralPath $workFile).Length | Should -Be $sizeBefore
        (Get-Content -LiteralPath $workFile -Raw) | Should -Be $original
    }

    It 'Accepts in-place step when output is smaller' {
        $workDir = Join-Path $TestDrive 'inplace-shrink'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.dat'
        $original = 'A' * 100
        Set-Content -LiteralPath $workFile -Value $original -NoNewline

        $sizeBefore = (Get-Item -LiteralPath $workFile).Length
        $step = [PSCustomObject]@{
            Name = 'shrink-inplace'; Executable = 'powershell.exe'
            Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "Set-Content -LiteralPath ''%INPUTFILE%'' -Value (''X''*10) -NoNewline"'
            Handler = $null; Mode = 'InPlace'; Gate = $null
        }
        $settings = Get-FoConfig

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly

        $result.Accepted | Should -Be $true
        (Get-Item -LiteralPath $workFile).Length | Should -Be 10
        (Get-Item -LiteralPath $workFile).Length | Should -BeLessThan $sizeBefore
    }

    It 'Treats INPUTFILE-only steps as in-place even when Mode is TempOutput' {
        $workDir = Join-Path $TestDrive 'inplace-shntool-style'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.dat'
        $original = 'B' * 64
        Set-Content -LiteralPath $workFile -Value $original -NoNewline

        $sizeBefore = (Get-Item -LiteralPath $workFile).Length
        $step = [PSCustomObject]@{
            Name = 'grow-inputfile-only'; Executable = 'cmd.exe'
            Arguments = '/c echo PAD>>"%INPUTFILE%"'; Handler = $null; Mode = 'TempOutput'; Gate = $null
        }
        $settings = Get-FoConfig

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly

        $result.Accepted | Should -Be $false
        (Get-Item -LiteralPath $workFile).Length | Should -Be $sizeBefore
    }
}

Describe 'Invoke-FoPlugin exit-code ranges' -Tag Unit {
    It 'Rejects smaller output when exit code is outside the accepted range' {
        $workDir = Join-Path $TestDrive 'exit-range-reject'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.dat'
        $original = 'A' * 100
        Set-Content -LiteralPath $workFile -Value $original -NoNewline

        $step = [PSCustomObject]@{
            Name = 'shrink-exit1'; Executable = 'powershell.exe'
            Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "Set-Content -LiteralPath ''%TMPOUTPUTFILE%'' -Value (''X''*10) -NoNewline; exit 1"'
            Handler = $null; Mode = 'TempOutput'; Gate = $null
            ErrorMin = 0; ErrorMax = 0
        }
        $settings = Get-FoConfig

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly

        $result.ExitCode | Should -Be 1
        $result.Accepted | Should -Be $false
        (Get-Item -LiteralPath $workFile).Length | Should -Be 100
    }

    It 'Accepts smaller output when exit code is inside a custom success range' {
        $workDir = Join-Path $TestDrive 'exit-range-accept'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.dat'
        $original = 'A' * 100
        Set-Content -LiteralPath $workFile -Value $original -NoNewline

        $step = [PSCustomObject]@{
            Name = 'shrink-exit1-ok'; Executable = 'powershell.exe'
            Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "Set-Content -LiteralPath ''%TMPOUTPUTFILE%'' -Value (''X''*10) -NoNewline; exit 1"'
            Handler = $null; Mode = 'TempOutput'; Gate = $null
            ErrorMin = 1; ErrorMax = 1
        }
        $settings = Get-FoConfig

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly

        $result.ExitCode | Should -Be 1
        $result.Accepted | Should -Be $true
        (Get-Item -LiteralPath $workFile).Length | Should -Be 10
    }
}

Describe 'Invoke-FoPlugin handler map' -Tag Unit {
    It 'Warns and fails when handler name is unknown' {
        $workDir = Join-Path $TestDrive 'unknown-handler'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.dat'
        Set-Content -LiteralPath $workFile -Value ('A' * 64) -NoNewline

        $step = [PSCustomObject]@{
            Name = 'bad-handler'
            Handler = 'NonexistentHandler'
            Arguments = $null
            Mode = 'TempOutput'
            Gate = $null
        }
        $settings = Get-FoConfig
        $warnings = @()

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly -WarningVariable warnings -WarningAction Continue

        ($warnings | Out-String) | Should -Match "Unknown handler 'NonexistentHandler'"
        $result.ExitCode | Should -Be 1
        $result.Accepted | Should -Be $false
    }
}

Describe 'Invoke-FoPlugin timeouts' -Tag Unit {
    It 'Fails quickly when a plugin step exceeds PluginTimeoutSeconds' {
        $workDir = Join-Path $TestDrive 'plugin-timeout'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.dat'
        Set-Content -LiteralPath $workFile -Value ('A' * 64) -NoNewline

        $step = [PSCustomObject]@{
            Name = 'sleep'; Executable = 'powershell.exe'
            Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "Start-Sleep -Seconds 30"'
            Handler = $null; Mode = 'TempOutput'; Gate = $null
        }
        $settings = Get-FoConfig
        $settings.PluginTimeoutSeconds = 1

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly
        $sw.Stop()

        $result.Reason | Should -Be 'Timeout'
        $result.Accepted | Should -Be $false
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 10
    }

    It 'Rolls back in-place changes when a plugin step times out' {
        $workDir = Join-Path $TestDrive 'inplace-timeout'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.dat'
        $original = 'A' * 100
        Set-Content -LiteralPath $workFile -Value $original -NoNewline

        $step = [PSCustomObject]@{
            Name = 'timeout-inplace'
            Executable = 'powershell.exe'
            Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "Set-Content -LiteralPath ''%INPUTFILE%'' -Value (''X''*10) -NoNewline; Start-Sleep -Seconds 30"'
            Handler = $null
            Mode = 'InPlace'
            Gate = $null
        }

        $settings = Get-FoConfig
        $settings.PluginTimeoutSeconds = 1

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly
        $sw.Stop()

        $result.Reason | Should -Be 'Timeout'
        $result.Accepted | Should -Be $false
        (Get-Content -LiteralPath $workFile -Raw) | Should -Be $original
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 10
    }

    It 'Completes when a plugin writes large stderr volume' {
        $workDir = Join-Path $TestDrive 'plugin-stderr'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.dat'
        Set-Content -LiteralPath $workFile -Value ('A' * 64) -NoNewline

        $step = [PSCustomObject]@{
            Name = 'stderr-flood'
            Executable = 'powershell.exe'
            Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "1..5000 | ForEach-Object { [Console]::Error.WriteLine($_) }; exit 0"'
            Handler = $null; Mode = 'TempOutput'; Gate = $null
        }
        $settings = Get-FoConfig
        $settings.PluginTimeoutSeconds = 30
        $settings.MaxPluginStderrBytes = 1024

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly
        $sw.Stop()

        $result.ExitCode | Should -Be 0
        $result.Reason | Should -BeNullOrEmpty
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 15
    }
}

Describe 'Invoke-FoPlugin DisablePluginMask' -Tag Unit {
    It 'Does not skip exe steps when mask matches step name only' {
        $workDir = Join-Path $TestDrive 'mask-name-only'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.dat'
        Set-Content -LiteralPath $workFile -Value ('A' * 64) -NoNewline

        $step = [PSCustomObject]@{
            Name = 'PNG Optimizer'
            Executable = 'cmd.exe'
            Arguments = '/c exit 0'
            Handler = $null
            Mode = 'TempOutput'
            Gate = $null
        }
        $settings = Get-FoConfig
        $settings.DisablePluginMask = 'PNG'

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly

        $result.Skipped | Should -Be $false
    }

    It 'Skips exe steps when mask matches command line' {
        $workDir = Join-Path $TestDrive 'mask-command-line'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.dat'
        Set-Content -LiteralPath $workFile -Value ('A' * 64) -NoNewline

        $step = [PSCustomObject]@{
            Name = 'noop'
            Executable = 'cmd.exe'
            Arguments = '/c exit 0'
            Handler = $null
            Mode = 'TempOutput'
            Gate = $null
        }
        $settings = Get-FoConfig
        $settings.DisablePluginMask = 'CMD.EXE'

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly

        $result.Skipped | Should -Be $true
    }

    It 'Reports real sizes when steps are skipped by mask' {
        $workDir = Join-Path $TestDrive 'mask-sizes'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.bin'
        $data = 'A' * 100
        Set-Content -LiteralPath $workFile -Value $data -NoNewline

        $step = [PSCustomObject]@{
            Name = 'noop-mask'
            Executable = 'cmd.exe'
            Arguments = '/c rem %TMPINPUTFILE%'
            Handler = $null
            Mode = 'TempInput'
            Gate = $null
        }
        $settings = Get-FoConfig
        $settings.DisablePluginMask = 'cmd.exe'

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly

        $result.Skipped | Should -Be $true
        $result.SizeBefore | Should -Be 100
        $result.SizeAfter | Should -Be 100
    }

    It 'Skips handler steps when mask matches handler name' {
        $workDir = Join-Path $TestDrive 'mask-handler'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.js'
        Set-Content -LiteralPath $workFile -Value 'var x = 1;' -NoNewline

        $step = [PSCustomObject]@{
            Name = 'jsmin step'
            Handler = 'JsMinPipe'
            Arguments = $null
            Mode = 'TempOutput'
            Gate = $null
        }
        $settings = Get-FoConfig
        $settings.DisablePluginMask = 'JsMinPipe'

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly

        $result.Skipped | Should -Be $true
    }
}

Describe 'Invoke-FoPlugin custom TempDirectory' -Tag Unit {
    It 'Creates TempDirectory when missing and completes TempOutput steps' {
        $workDir = Join-Path $TestDrive 'temp-custom-work'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test.dat'
        $original = 'A' * 100
        Set-Content -LiteralPath $workFile -Value $original -NoNewline

        $customTemp = Join-Path $TestDrive 'new-temp-dir'
        if (Test-Path -LiteralPath $customTemp) {
            Remove-Item -LiteralPath $customTemp -Recurse -Force
        }

        $step = [PSCustomObject]@{
            Name = 'shrink-custom-temp'
            Executable = 'powershell.exe'
            Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "Set-Content -LiteralPath ''%TMPOUTPUTFILE%'' -Value (''X''*10) -NoNewline"'
            Handler = $null
            Mode = 'TempOutput'
            Gate = $null
        }
        $settings = Get-FoConfig
        $settings.TempDirectory = $customTemp

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly

        Test-Path -LiteralPath $customTemp | Should -Be $true
        $result.Accepted | Should -Be $true
        (Get-Item -LiteralPath $workFile).Length | Should -Be 10
    }
}

Describe 'Invoke-FoPlugin zero-byte input' -Tag Unit {
    It 'Skips zero-byte files with ZeroByte reason' {
        $workDir = Join-Path $TestDrive 'zero-byte'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'empty.dat'
        Set-Content -LiteralPath $workFile -Value '' -NoNewline

        $step = [PSCustomObject]@{
            Name = 'noop'
            Executable = 'cmd.exe'
            Arguments = '/c exit 0'
            Handler = $null
            Mode = 'TempOutput'
            Gate = $null
        }
        $settings = Get-FoConfig

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly

        $result.Skipped | Should -Be $true
        $result.Reason | Should -Be 'ZeroByte'
        $result.Accepted | Should -Be $false
    }
}

Describe 'Pipeline argument quoting' -Tag Unit {
    It 'Substitutes pngrewrite placeholders without double-quoting spaced paths' {
        $png = Join-Path $PSScriptRoot 'Fixtures\Images\pngsuite\basn0g08.png'
        $ctx = New-FoFileContext -InputFile $png -Settings (Get-FoConfig)
        $step = @(Get-FoPipeline -GroupName PNG -Context $ctx) |
            Where-Object { $_.Name -like 'pngrewrite*' } |
            Select-Object -First 1
        $step | Should -Not -BeNullOrEmpty

        $inputPath = Join-Path $TestDrive 'my images\test file.png'
        $outPath = Join-Path $TestDrive 'my images\test file.out.png'
        $args = $step.Arguments
        $args = $args.Replace('%INPUTFILE%', (Format-FoProcessArgument $inputPath))
        $args = $args.Replace('%TMPOUTPUTFILE%', (Format-FoProcessArgument $outPath))

        $args | Should -Not -Match '""'
        $args | Should -Match ([regex]::Escape((Format-FoProcessArgument $inputPath)))
        $args | Should -Match ([regex]::Escape((Format-FoProcessArgument $outPath)))
    }
}

Describe 'Invoke-FoPlugin spaced paths' -Tag Unit {
    It 'Runs TempOutput steps when paths contain spaces' {
        $workDir = Join-Path $TestDrive 'my images'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $workFile = Join-Path $workDir 'test file.dat'
        $original = 'A' * 100
        Set-Content -LiteralPath $workFile -Value $original -NoNewline

        $step = [PSCustomObject]@{
            Name = 'shrink-spaced'
            Executable = 'powershell.exe'
            Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "Set-Content -LiteralPath ''%TMPOUTPUTFILE%'' -Value (''X''*10) -NoNewline"'
            Handler = $null; Mode = 'TempOutput'; Gate = $null
        }
        $settings = Get-FoConfig

        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly

        $result.Accepted | Should -Be $true
        (Get-Item -LiteralPath $workFile).Length | Should -Be 10
    }
}
