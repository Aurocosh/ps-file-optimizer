BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'CLI script exit codes' -Tag Unit {
    BeforeAll {
        $script:FoCliModuleRoot = Split-Path -Parent $PSScriptRoot

        function script:Invoke-FoCliScriptExitCode {
            param(
                [string]$ScriptPath,
                [string[]]$ArgumentList = @(),
                [string]$Command
            )

            # Child CLI scripts write validation messages to stderr. Use Start-Process with
            # stream redirection so both pwsh and Windows PowerShell can assert exit codes
            # without surfacing native stderr as test errors.
            $stdoutPath = Join-Path $TestDrive ("fo-cli-stdout-{0}.log" -f [guid]::NewGuid().ToString('N'))
            $stderrPath = Join-Path $TestDrive ("fo-cli-stderr-{0}.log" -f [guid]::NewGuid().ToString('N'))
            $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass')
            if ($Command) {
                $argList += @('-Command', $Command)
            }
            else {
                $argList += @('-File', $ScriptPath)
                if ($ArgumentList) { $argList += $ArgumentList }
            }

            $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -NoNewWindow -Wait -PassThru `
                -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
            return [PSCustomObject]@{
                ExitCode = $proc.ExitCode
                StdOut   = if (Test-Path -LiteralPath $stdoutPath) {
                    $content = Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
                    if ($null -eq $content) { '' } else { $content.Trim() }
                } else { '' }
            }
        }
    }

    It 'Optimize-File.ps1 -Version prints ModuleVersion and exits 0' {
        $scriptPath = Join-Path $script:FoCliModuleRoot 'Scripts\Optimize-File.ps1'
        $manifestPath = Join-Path $script:FoCliModuleRoot 'FileOptimizer.psd1'
        $expectedVersion = (Import-FoPsd1File -Path $manifestPath).ModuleVersion.ToString()
        $command = "& '$($scriptPath.Replace("'", "''"))' -Version"
        $result = Invoke-FoCliScriptExitCode -Command $command
        $result.ExitCode | Should -Be 0
        $result.StdOut | Should -Be $expectedVersion
    }

    It 'Optimize-File.ps1 exits 1 when no paths are specified' {
        $scriptPath = Join-Path $script:FoCliModuleRoot 'Scripts\Optimize-File.ps1'
        $exitCode = (Invoke-FoCliScriptExitCode -ScriptPath $scriptPath).ExitCode
        $exitCode | Should -Be 1
    }

    It 'Optimize-File.ps1 exits 0 for -WhatIf on an existing file' {
        $file = Join-Path $TestDrive 'cli-whatif.png'
        [System.IO.File]::WriteAllBytes($file, [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0))
        $scriptPath = Join-Path $script:FoCliModuleRoot 'Scripts\Optimize-File.ps1'
        $command = "& '$scriptPath' '$($file.Replace("'", "''"))' -WhatIf"
        $exitCode = (Invoke-FoCliScriptExitCode -Command $command).ExitCode
        $exitCode | Should -Be 0
    }

    It 'Optimize-File.ps1 accepts -ContinueOnError without failing' {
        $file = Join-Path $TestDrive 'cli-continue.png'
        [System.IO.File]::WriteAllBytes($file, [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0))
        $scriptPath = Join-Path $script:FoCliModuleRoot 'Scripts\Optimize-File.ps1'
        $command = "& '$scriptPath' '$($file.Replace("'", "''"))' -WhatIf -ContinueOnError"
        $exitCode = (Invoke-FoCliScriptExitCode -Command $command).ExitCode
        $exitCode | Should -Be 0
    }

    It 'Undo-Optimization.ps1 exits 1 when neither -Path nor -Last is given' {
        $scriptPath = Join-Path $script:FoCliModuleRoot 'Scripts\Undo-Optimization.ps1'
        $exitCode = (Invoke-FoCliScriptExitCode -ScriptPath $scriptPath).ExitCode
        $exitCode | Should -Be 1
    }

    It 'Install-Plugins.ps1 exits 0 for -WhatIf' {
        $scriptPath = Join-Path $script:FoCliModuleRoot 'Scripts\Install-Plugins.ps1'
        $exitCode = (Invoke-FoCliScriptExitCode -ScriptPath $scriptPath -ArgumentList @('-WhatIf', '-Mode', 'Remove')).ExitCode
        $exitCode | Should -Be 0
    }
}
