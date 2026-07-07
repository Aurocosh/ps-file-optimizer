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

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings -SearchMode PathOnly
        $sw.Stop()

        $result.ExitCode | Should -Be 0
        $result.Reason | Should -BeNullOrEmpty
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 15
    }
}
