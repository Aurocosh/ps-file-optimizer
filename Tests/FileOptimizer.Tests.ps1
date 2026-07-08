BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Format-FoFileSize' -Tag Unit {
    It 'Formats bytes' {
        Format-FoFileSize -Bytes 1024 | Should -Be '1.0 KB'
    }
}

Describe 'Merge-FoSettings' -Tag Unit {
    It 'Explicit parameter overrides defaults' {
        $s = Merge-FoSettings -BoundParameters @{ Level = 9 }
        $s.Level | Should -Be 9
        $s.OutputMode | Should -Be 'TempMove'
    }
}

Describe 'Config merge' -Tag Unit {
    It 'Bound Level overrides defaults via Merge-FoSettings' {
        $s = Merge-FoSettings -BoundParameters @{ Level = 7 }
        $s.Level | Should -Be 7
    }
}

Describe 'Resolve-FoPluginExecutable' -Tag Unit {
    It 'Finds portable plugin when present' -Skip:(-not (Test-FoPluginsAvailable -RequiredExecutables @('oxipng.exe'))) {
        $pluginPath = Get-FoTestPluginPath
        $r = Resolve-FoPluginExecutable -Name 'oxipng.exe' -SearchMode PortableOnly -PluginPath $pluginPath
        $r.Found | Should -Be $true
    }

    It 'PortableOnly returns not found for bad path' {
        $r = Resolve-FoPluginExecutable -Name 'nonexistent_fo_tool_12345.exe' -SearchMode PortableOnly -PluginPath 'C:\nonexistent'
        $r.Found | Should -Be $false
    }
}

Describe 'Get-FoPipeline PNG' -Tag Unit {
    It 'Returns multiple steps' {
        $png = Join-Path $env:TEMP "fo_pipe_$(Get-Random).png"
        New-FoTestPng -Path $png
        try {
            $ctx = New-FoFileContext -InputFile $png -Settings (Get-FoConfig)
            $steps = Get-FoPipeline -GroupName PNG -Context $ctx
            ($steps.Count -gt 5) | Should -Be $true
        }
        finally {
            Remove-Item $png -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Pipeline WhatIf snapshot' -Tag Unit {
    It 'PNG pipeline reports many steps' {
        $png = Join-Path $env:TEMP "fo_whatif_$(Get-Random).png"
        New-FoTestPng -Path $png
        try {
            $r = Optimize-FoFile -Path $png -PluginPath 'C:\nonexistent' -PluginSearchMode PortableOnly -WhatIf
            $r[0].Status | Should -Be 'WhatIf'
            ($r[0].Steps.Count -gt 5) | Should -Be $true
        }
        finally {
            Remove-Item $png -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Invoke-FoOutputMode TempMove' -Tag Unit {
    It 'Moves original to backup' {
        $dir = Join-Path $env:TEMP "FoTest_$(Get-Random)"
        $srcDir = Join-Path $dir 'src'
        $bakRoot = Join-Path $dir 'bak'
        New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
        $orig = Join-Path $srcDir 'a.txt'
        $opt = Join-Path $env:TEMP "opt_$(Get-Random).txt"
        Set-Content -LiteralPath $orig -Value 'original content here' -NoNewline
        Set-Content -LiteralPath $opt -Value 'opt' -NoNewline

        try {
            $s = Get-FoConfig
            $s.OutputMode = 'TempMove'
            $s.TempBackupPath = $bakRoot
            $r = Invoke-FoOutputMode -SourceFile $opt -TargetPath $orig -Settings $s
            ($null -ne $r.BackupPath) | Should -Be $true
            (Test-Path -LiteralPath $orig) | Should -Be $true
        }
        finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $opt -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Invoke-FoOutputMode failure recovery' -Tag Unit {
    It 'Restores original when promote fails after backup move (TempMove)' {
        $dir = Join-Path $env:TEMP "FoTestRecover_$(Get-Random)"
        $srcDir = Join-Path $dir 'src'
        $bakRoot = Join-Path $dir 'bak'
        New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
        $orig = Join-Path $srcDir 'a.txt'
        $opt = Join-Path $env:TEMP "opt_$(Get-Random).txt"
        $originalContent = 'original content here'
        Set-Content -LiteralPath $orig -Value $originalContent -NoNewline
        Set-Content -LiteralPath $opt -Value 'opt' -NoNewline

        try {
            $env:FO_TEST_ORIG = $orig
            $env:FO_TEST_OPT = $opt
            $env:FO_TEST_BAK = $bakRoot
            InModuleScope FileOptimizer {
                $realMoveItem = Get-Command Move-Item -Module Microsoft.PowerShell.Management
                Mock Move-Item {
                    param($LiteralPath, $Destination, $Force)
                    if ($LiteralPath -like '*.fo-staging') {
                        throw 'Simulated promote failure'
                    }
                    & $realMoveItem @PSBoundParameters
                }

                $s = Get-FoConfig
                $s.OutputMode = 'TempMove'
                $s.TempBackupPath = $env:FO_TEST_BAK
                { Invoke-FoOutputMode -SourceFile $env:FO_TEST_OPT -TargetPath $env:FO_TEST_ORIG -Settings $s } |
                    Should -Throw 'Simulated promote failure'
            }

            (Test-Path -LiteralPath $orig) | Should -Be $true
            (Get-Content -LiteralPath $orig -Raw) | Should -Be $originalContent
            (Test-Path -LiteralPath ($orig + '.fo-staging')) | Should -Be $false
        }
        finally {
            Remove-Item Env:FO_TEST_ORIG, Env:FO_TEST_OPT, Env:FO_TEST_BAK -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $opt -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Invoke-FoOutputMode TempMove backup paths' -Tag Unit {
    It 'Creates distinct backups for same-named files in different directories' {
        $dir = Join-Path $env:TEMP "FoTestCollision_$(Get-Random)"
        $dirA = Join-Path $dir 'folderA'
        $dirB = Join-Path $dir 'folderB'
        $bakRoot = Join-Path $dir 'bak'
        New-Item -ItemType Directory -Path $dirA, $dirB -Force | Out-Null
        $origA = Join-Path $dirA 'same.txt'
        $origB = Join-Path $dirB 'same.txt'
        $optA = Join-Path $env:TEMP "optA_$(Get-Random).txt"
        $optB = Join-Path $env:TEMP "optB_$(Get-Random).txt"
        Set-Content -LiteralPath $origA -Value 'content-a' -NoNewline
        Set-Content -LiteralPath $origB -Value 'content-b' -NoNewline
        Set-Content -LiteralPath $optA -Value 'a' -NoNewline
        Set-Content -LiteralPath $optB -Value 'b' -NoNewline

        try {
            $s = Get-FoConfig
            $s.OutputMode = 'TempMove'
            $s.TempBackupPath = $bakRoot
            $rA = Invoke-FoOutputMode -SourceFile $optA -TargetPath $origA -Settings $s
            $rB = Invoke-FoOutputMode -SourceFile $optB -TargetPath $origB -Settings $s

            $rA.BackupPath | Should -Not -Be $rB.BackupPath
            (Test-Path -LiteralPath $rA.BackupPath) | Should -Be $true
            (Test-Path -LiteralPath $rB.BackupPath) | Should -Be $true
            (Get-Content -LiteralPath $rA.BackupPath -Raw) | Should -Be 'content-a'
            (Get-Content -LiteralPath $rB.BackupPath -Raw) | Should -Be 'content-b'
        }
        finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $optA, $optB -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Uses target-relative backup paths independent of current working directory' {
        $dir = Join-Path $env:TEMP "FoTestCwd_$(Get-Random)"
        $srcDir = Join-Path $dir 'src'
        $otherDir = Join-Path $dir 'other-cwd'
        $bakRoot = Join-Path $dir 'bak'
        New-Item -ItemType Directory -Path $srcDir, $otherDir -Force | Out-Null
        $orig = Join-Path $srcDir 'same.txt'
        $opt = Join-Path $env:TEMP "opt_cwd_$(Get-Random).txt"
        Set-Content -LiteralPath $orig -Value 'before' -NoNewline
        Set-Content -LiteralPath $opt -Value 'after' -NoNewline

        Push-Location $otherDir
        try {
            $s = Get-FoConfig
            $s.OutputMode = 'TempMove'
            $s.TempBackupPath = $bakRoot
            $r = Invoke-FoOutputMode -SourceFile $opt -TargetPath $orig -Settings $s
            $expectedRoot = (Get-Item -LiteralPath $bakRoot).FullName
            $r.BackupPath | Should -BeLike ((Join-Path $expectedRoot '*\src\same.txt'))
            (Test-Path -LiteralPath $r.BackupPath) | Should -Be $true
        }
        finally {
            Pop-Location
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $opt -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'History and rollback' -Tag Unit {
    It 'Records entry and rolls back TempMove' {
        $histDir = Join-Path $env:TEMP "FoHist_$(Get-Random)"
        $histFile = Join-Path $histDir 'history.json'
        $workDir = Join-Path $histDir 'work'
        $bakRoot = Join-Path $histDir 'backups'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $orig = Join-Path $workDir 'doc.txt'
        $opt = Join-Path $env:TEMP "fo_opt_$(Get-Random).txt"
        Set-Content -LiteralPath $orig -Value 'original-long-content' -NoNewline
        Set-Content -LiteralPath $opt -Value 'x' -NoNewline

        Push-Location $workDir
        try {
            $s = Get-FoConfig
            $s.OutputMode = 'TempMove'
            $s.TempBackupPath = $bakRoot
            $s.HistoryPath = $histFile
            $s.HistoryEnabled = $true

            $out = Invoke-FoOutputMode -SourceFile $opt -TargetPath $orig -Settings $s
            $result = [PSCustomObject]@{
                Path         = $orig
                OriginalSize = 21
                FinalSize    = 1
                OutputPath   = $orig
                BackupPath   = $out.BackupPath
                OutputMode   = 'TempMove'
            }
            Add-FoHistoryEntry -Result $result -Settings $s

            $hist = @(Get-FoHistory -Last 1 -HistoryPath $histFile -Format Object)
            $hist.Count | Should -Be 1
            $hist[0].ReversalStatus | Should -Be 'Pending'
            $hist[0].TargetPath | Should -Be $orig
            $hist[0].OriginalPath | Should -Be $orig

            $undo = @(Undo-FoOptimization -Last 1 -HistoryPath $histFile)
            ($undo.Count -gt 0) | Should -Be $true
            (Get-Content -LiteralPath $orig -Raw) | Should -Be 'original-long-content'

            $hist2 = @(Get-FoHistory -Last 1 -HistoryPath $histFile -Format Object)
            $hist2[0].ReversalStatus | Should -Be 'Reversed'
        }
        finally {
            Pop-Location
            Remove-Item -LiteralPath $histDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $opt -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Assigns unique history IDs for rapid consecutive entries' {
        $histDir = Join-Path $env:TEMP "FoHistIds_$(Get-Random)"
        $histFile = Join-Path $histDir 'history.json'
        New-Item -ItemType Directory -Path $histDir -Force | Out-Null

        try {
            $s = Get-FoConfig
            $s.HistoryPath = $histFile
            $s.HistoryEnabled = $true

            $base = [PSCustomObject]@{
                Path         = (Join-Path $histDir 'a.txt')
                OriginalSize = 10
                FinalSize    = 5
                OutputPath   = (Join-Path $histDir 'a.txt')
                BackupPath   = $null
                OutputMode   = 'Replace'
            }
            Add-FoHistoryEntry -Result $base -Settings $s
            Add-FoHistoryEntry -Result $base -Settings $s

            $ids = @((Get-FoHistory -HistoryPath $histFile -Format Object -Last 2) | ForEach-Object { $_.Id })
            $ids.Count | Should -Be 2
            $ids[0] | Should -Not -Be $ids[1]
        }
        finally {
            Remove-Item -LiteralPath $histDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Allows only one parallel undo to reverse a single pending entry' {
        $histDir = Join-Path $env:TEMP "FoHistParallel_$(Get-Random)"
        $histFile = Join-Path $histDir 'history.json'
        $workDir = Join-Path $histDir 'work'
        $bakRoot = Join-Path $histDir 'backups'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $orig = Join-Path $workDir 'doc.txt'
        $opt = Join-Path $env:TEMP "fo_opt_parallel_$(Get-Random).txt"
        Set-Content -LiteralPath $orig -Value 'original-long-content' -NoNewline
        Set-Content -LiteralPath $opt -Value 'x' -NoNewline

        Push-Location $workDir
        try {
            $s = Get-FoConfig
            $s.OutputMode = 'TempMove'
            $s.TempBackupPath = $bakRoot
            $s.HistoryPath = $histFile
            $s.HistoryEnabled = $true

            $out = Invoke-FoOutputMode -SourceFile $opt -TargetPath $orig -Settings $s
            $result = [PSCustomObject]@{
                Path         = $orig
                OriginalSize = 21
                FinalSize    = 1
                OutputPath   = $orig
                BackupPath   = $out.BackupPath
                OutputMode   = 'TempMove'
            }
            Add-FoHistoryEntry -Result $result -Settings $s

            $moduleRoot = (Get-Module FileOptimizer).ModuleBase
            $undoScript = {
                param($HistoryPath, $ModuleRoot)
                Import-Module (Join-Path $ModuleRoot 'FileOptimizer.psd1') -Force
                return @(Undo-FoOptimization -Last 1 -HistoryPath $HistoryPath)
            }
            $jobA = Start-Job -ScriptBlock $undoScript -ArgumentList $histFile, $moduleRoot
            $jobB = Start-Job -ScriptBlock $undoScript -ArgumentList $histFile, $moduleRoot
            Wait-Job -Job $jobA, $jobB | Out-Null
            $results = @()
            foreach ($job in @($jobA, $jobB)) {
                $received = Receive-Job -Job $job
                if ($null -ne $received) {
                    $results += @($received)
                }
            }
            Remove-Job -Job $jobA, $jobB -Force

            @($results | Where-Object { $_.Status -eq 'Reversed' }).Count | Should -Be 1
            @((Get-FoHistory -HistoryPath $histFile -Format Object) | Where-Object { $_.ReversalStatus -eq 'Reversed' }).Count | Should -Be 1
        }
        finally {
            Pop-Location
            Remove-Item -LiteralPath $histDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $opt -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Missing tools policy' -Tag Unit {
    It 'Continues per-step when tools missing (FileOptimizer parity)' {
        $png = Join-Path $env:TEMP "fo_miss_$(Get-Random).png"
        New-FoTestPng -Path $png
        try {
            $r = Optimize-FoFile -Path $png -PluginPath 'C:\nonexistent_plugins' -PluginSearchMode PortableOnly -ErrorAction Stop
            $r[0].Status | Should -BeIn @('Unchanged', 'Optimized')
        }
        finally {
            Remove-Item $png -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Skips with SkipMissingTools' {
        $png = Join-Path $env:TEMP "fo_skip_$(Get-Random).png"
        New-FoTestPng -Path $png
        try {
            $r = Optimize-FoFile -Path $png -PluginPath 'C:\nonexistent_plugins' -PluginSearchMode PortableOnly -SkipMissingTools:$true
            $r[0].Status | Should -Be 'Skipped'
        }
        finally {
            Remove-Item $png -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Optimize-FoFile -ContinueOnError' -Tag Unit {
    BeforeAll {
        if (-not (Get-Module -Name FileOptimizer)) {
            Import-Module (Join-Path (Get-FoTestModuleRoot) 'FileOptimizer.psd1') -Force
        }
    }

    It 'Continues batch when -ContinueOnError is set' {
        $good = Join-Path $TestDrive 'continue-good.png'
        $bad = Join-Path $TestDrive 'continue-bad.png'
        New-FoTestPng -Path $good
        New-FoTestPng -Path $bad

        InModuleScope -ArgumentList $good, $bad FileOptimizer {
            param($GoodPath, $BadPath)

            Mock Invoke-FoPluginChain {
                if ($Path -eq $BadPath) { throw 'simulated optimize failure' }
                return [PSCustomObject]@{
                    Path         = $Path
                    Status       = 'Optimized'
                    OriginalSize = 100
                    FinalSize    = 50
                    PercentSaved = 50
                    OutputPath   = $Path
                }
            }

            $results = @(Optimize-FoFile -Path @($BadPath, $GoodPath) -ContinueOnError -Confirm:$false)
            $results.Count | Should -Be 2
            @($results | Where-Object { $_.Status -eq 'Error' }).Count | Should -Be 1
            @($results | Where-Object { $_.Status -eq 'Optimized' }).Count | Should -Be 1
        }
    }

    It 'Continues batch when -ContinueOnError is set even if SkipMissingTools is false' {
        $good = Join-Path $TestDrive 'continue-skip-good.png'
        $bad = Join-Path $TestDrive 'continue-skip-bad.png'
        New-FoTestPng -Path $good
        New-FoTestPng -Path $bad

        InModuleScope -ArgumentList $good, $bad FileOptimizer {
            param($GoodPath, $BadPath)

            Mock Invoke-FoPluginChain {
                if ($Path -eq $BadPath) { throw 'simulated optimize failure' }
                return [PSCustomObject]@{
                    Path         = $Path
                    Status       = 'Optimized'
                    OriginalSize = 100
                    FinalSize    = 50
                    PercentSaved = 50
                    OutputPath   = $Path
                }
            }

            $results = @(Optimize-FoFile -Path @($BadPath, $GoodPath) -ContinueOnError -SkipMissingTools:$false -Confirm:$false)
            $results.Count | Should -Be 2
            @($results | Where-Object { $_.Status -eq 'Error' }).Count | Should -Be 1
            @($results | Where-Object { $_.Status -eq 'Optimized' }).Count | Should -Be 1
        }
    }

    It 'Stops batch on error by default' {
        $good = Join-Path $TestDrive 'stop-good.png'
        $bad = Join-Path $TestDrive 'stop-bad.png'
        New-FoTestPng -Path $good
        New-FoTestPng -Path $bad

        InModuleScope -ArgumentList $good, $bad FileOptimizer {
            param($GoodPath, $BadPath)

            Mock Invoke-FoPluginChain {
                if ($Path -eq $BadPath) { throw 'simulated optimize failure' }
                return [PSCustomObject]@{
                    Path         = $Path
                    Status       = 'Optimized'
                    OriginalSize = 100
                    FinalSize    = 50
                    PercentSaved = 50
                    OutputPath   = $Path
                }
            }

            { Optimize-FoFile -Path @($BadPath, $GoodPath) -Confirm:$false -ErrorAction Stop } |
                Should -Throw 'simulated optimize failure'
        }
    }
}

Describe 'Extension map' -Tag Unit {
    It 'Loads extension map with many entries' {
        $mapPath = Join-Path (Get-FoTestModuleRoot) 'Data\ExtensionMap.psd1'
        $map = Import-FoPsd1File -Path $mapPath
        ($map.Keys.Count -ge 370) | Should -Be $true
    }
}

Describe 'Get-FoRequiredPluginExecutables' -Tag Unit {
    It 'Install plan lists all pipeline executables for x64' {
        $dir = Join-Path $env:TEMP "FoInstallPlan_$(Get-Random)"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $result = Install-FoPlugins -Mode FullPortable -Architecture 64 -DestinationPath $dir -WhatIf
            $result.ExecutablesNeeded.Count | Should -BeGreaterThan 50
            ($result.ExecutablesNeeded -contains 'oxipng.exe') | Should -Be $true
            ($result.ExecutablesNeeded -contains 'defluff.exe') | Should -Be $true
            ($result.ExecutablesNeeded -contains 'gswin64c.exe') | Should -Be $true
        }
        finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Install plan uses x86 Ghostscript and omits 64-only tools for Architecture 32' {
        $dir = Join-Path $env:TEMP "FoInstallPlan32_$(Get-Random)"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $result = Install-FoPlugins -Mode FullPortable -Architecture 32 -DestinationPath $dir -WhatIf
            ($result.ExecutablesNeeded -contains 'gswin32c.exe') | Should -Be $true
            ($result.ExecutablesNeeded -contains 'gswin64c.exe') | Should -Be $false
            ($result.ExecutablesNeeded -contains 'minify.exe') | Should -Be $false
            ($result.ExecutablesNeeded -contains 'optivorbis.exe') | Should -Be $false
            ($result.ExecutablesNeeded -contains 'tinydng-cli.exe') | Should -Be $false
        }
        finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Install-FoPlugins planning' -Tag Unit {
    It 'Missing mode skips download when all executables are present' {
        $dir = Join-Path $env:TEMP "FoInstallTest_$(Get-Random)"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $plan = Install-FoPlugins -Mode FullPortable -DestinationPath $dir -WhatIf
            foreach ($exe in $plan.ExecutablesNeeded) {
                New-Item -ItemType File -Path (Join-Path $dir $exe) -Force | Out-Null
            }
            $result = Install-FoPlugins -Mode Missing -DestinationPath $dir
            $result.Downloaded | Should -Be $false
            $result.Extracted | Should -Be $false
            ($result.ExecutablesNeeded.Count) | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
