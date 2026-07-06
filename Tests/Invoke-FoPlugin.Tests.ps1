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
