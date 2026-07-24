BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Format-FoFileSize' -Tag Unit {
    It 'Formats bytes with Auto unit' {
        Format-FoFileSize -Bytes 1024 | Should -Be '1.0 KB'
    }

    It 'Formats fixed units' {
        Format-FoFileSize -Bytes 2048 -Unit Bytes | Should -Be '2,048 B'
        Format-FoFileSize -Bytes 2048 -Unit KB | Should -Be '2.0 KB'
        Format-FoFileSize -Bytes 2MB -Unit MB | Should -Be '2.00 MB'
        Format-FoFileSize -Bytes 2GB -Unit GB | Should -Be '2.00 GB'
    }

    It 'Formats size change strings' {
        InModuleScope FileOptimizer {
            Format-FoSizeChange -OriginalSize 2000 -FinalSize 1000 -Unit Bytes | Should -Be '2,000 B -> 1,000 B (-50%)'
        }
    }
}

Describe 'Format-FoOptimizeResultRow' -Tag Unit {
    It 'Builds a Standard table row with blank OutputPath when unchanged' {
        InModuleScope FileOptimizer {
            $row = Format-FoOptimizeResultRow -Result ([PSCustomObject]@{
                    Status       = 'Optimized'
                    Path         = 'C:\data\a.png'
                    OutputPath   = 'C:\data\a.png'
                    BackupPath   = 'C:\tmp\a.png'
                    OriginalSize = 2000
                    FinalSize    = 1000
                    OutputMode   = 'TempMove'
                    DurationMs   = 12
                }) -Unit Bytes
            $row.OutputPath | Should -BeNullOrEmpty
            $row.Size | Should -Be '2,000 B -> 1,000 B (-50%)'
            $row.Duration | Should -Be '12 ms'
        }
    }
}

Describe 'ReportVerbosity host output' -Tag Unit {
    It 'Keeps Compact and Verbose ReportVerbosity settings distinct' {
        InModuleScope FileOptimizer {
            $compact = Merge-FoSettings -BoundParameters @{ ReportVerbosity = 'Compact' }
            $verbose = Merge-FoSettings -BoundParameters @{ ReportVerbosity = 'Verbose' }
            Get-FoReportVerbosity -Settings $compact | Should -Be 'Compact'
            Get-FoReportVerbosity -Settings $verbose | Should -Be 'Verbose'
        }
    }

    It 'Formats Compact WhatIf summary lines' {
        InModuleScope FileOptimizer {
            $line = Format-FoOptimizeResultCompactLine -Result ([PSCustomObject]@{
                    Path   = 'C:\a.png'
                    Status = 'WhatIf'
                    Steps  = @(@{}, @{}, @{})
                })
            $line | Should -Be 'C:\a.png: what-if (3 steps)'
        }
    }

    It 'Builds Standard table text with size change' {
        InModuleScope FileOptimizer {
            $row = Format-FoOptimizeResultRow -Result ([PSCustomObject]@{
                    Status       = 'Optimized'
                    Path         = 'C:\a.png'
                    OutputPath   = 'C:\a.png'
                    BackupPath   = 'C:\bak\a.png'
                    OriginalSize = 2000
                    FinalSize    = 1000
                    OutputMode   = 'TempMove'
                    DurationMs   = 9
                }) -Unit Bytes
            $row.OriginalPath | Should -Be 'C:\a.png'
            $row.Size | Should -Be '2,000 B -> 1,000 B (-50%)'
            $table = @($row) | Format-Table -Property Status, OriginalPath, OutputPath, BackupPath, Size, OutputMode, Duration -AutoSize | Out-String
            $table | Should -Match 'OriginalPath'
            $table | Should -Match '2,000 B -> 1,000 B'
        }
    }
}

Describe 'Merge-FoSettings' -Tag Unit {
    It 'Explicit parameter overrides defaults' {
        $s = Merge-FoSettings -BoundParameters @{ Level = 9 }
        $s.Level | Should -Be 9
        $s.OutputMode | Should -Be 'TempMove'
    }

    It 'Falls back when PluginPath does not exist' {
        $fallback = Join-Path (Get-FoTestModuleRoot) 'Plugins64'
        if (-not (Test-Path -LiteralPath $fallback)) {
            $fallback = Join-Path (Get-FoTestModuleRoot) 'Plugins32'
        }

        $s = Merge-FoSettings -BoundParameters @{ PluginPath = 'C:\fo-missing-plugins-path-xyz' }
        if (Test-Path -LiteralPath $fallback) {
            $s.PluginPath | Should -Be ([System.IO.Path]::GetFullPath($fallback))
        }
        else {
            $s.PluginPath | Should -BeNullOrEmpty
        }
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

            $moduleRoot = Get-FoTestModuleRoot
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

Describe 'History and rollback output modes' -Tag Unit {
    It 'Records entry and rolls back BackupSuffix' {
        $histDir = Join-Path $env:TEMP "FoHistBkSfx_$(Get-Random)"
        $histFile = Join-Path $histDir 'history.json'
        $workDir = Join-Path $histDir 'work'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $orig = Join-Path $workDir 'doc.txt'
        $opt = Join-Path $env:TEMP "fo_opt_bksfx_$(Get-Random).txt"
        Set-Content -LiteralPath $orig -Value 'original-long-content' -NoNewline
        Set-Content -LiteralPath $opt -Value 'x' -NoNewline

        try {
            $s = Get-FoConfig
            $s.OutputMode = 'BackupSuffix'
            $s.BackupSuffix = '.bak'
            $s.HistoryPath = $histFile
            $s.HistoryEnabled = $true

            $out = Invoke-FoOutputMode -SourceFile $opt -TargetPath $orig -Settings $s
            $result = [PSCustomObject]@{
                Path         = $orig
                OriginalSize = 21
                FinalSize    = 1
                OutputPath   = $orig
                BackupPath   = $out.BackupPath
                OutputMode   = 'BackupSuffix'
            }
            Add-FoHistoryEntry -Result $result -Settings $s

            Undo-FoOptimization -Last 1 -HistoryPath $histFile | Out-Null
            (Get-Content -LiteralPath $orig -Raw) | Should -Be 'original-long-content'
            (Test-Path -LiteralPath ($orig + '.bak')) | Should -Be $false
        }
        finally {
            Remove-Item -LiteralPath $histDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $opt -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Records entry and rolls back BackupMove' {
        $histDir = Join-Path $env:TEMP "FoHistBkMove_$(Get-Random)"
        $histFile = Join-Path $histDir 'history.json'
        $workDir = Join-Path $histDir 'work'
        $bakRoot = Join-Path $histDir 'backups'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $orig = Join-Path $workDir 'doc.txt'
        $opt = Join-Path $env:TEMP "fo_opt_bkmove_$(Get-Random).txt"
        Set-Content -LiteralPath $orig -Value 'original-long-content' -NoNewline
        Set-Content -LiteralPath $opt -Value 'x' -NoNewline

        try {
            $s = Get-FoConfig
            $s.OutputMode = 'BackupMove'
            $s.BackupPath = $bakRoot
            $s.HistoryPath = $histFile
            $s.HistoryEnabled = $true

            $out = Invoke-FoOutputMode -SourceFile $opt -TargetPath $orig -Settings $s
            $result = [PSCustomObject]@{
                Path         = $orig
                OriginalSize = 21
                FinalSize    = 1
                OutputPath   = $orig
                BackupPath   = $out.BackupPath
                OutputMode   = 'BackupMove'
            }
            Add-FoHistoryEntry -Result $result -Settings $s

            Undo-FoOptimization -Last 1 -HistoryPath $histFile | Out-Null
            (Get-Content -LiteralPath $orig -Raw) | Should -Be 'original-long-content'
            (Test-Path -LiteralPath $out.BackupPath) | Should -Be $false
        }
        finally {
            Remove-Item -LiteralPath $histDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $opt -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Records entry and rolls back OptimizedSuffix' {
        $histDir = Join-Path $env:TEMP "FoHistOptSfx_$(Get-Random)"
        $histFile = Join-Path $histDir 'history.json'
        $workDir = Join-Path $histDir 'work'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $orig = Join-Path $workDir 'doc.txt'
        $opt = Join-Path $env:TEMP "fo_opt_optsfx_$(Get-Random).txt"
        Set-Content -LiteralPath $orig -Value 'original-long-content' -NoNewline
        Set-Content -LiteralPath $opt -Value 'x' -NoNewline

        try {
            $s = Get-FoConfig
            $s.OutputMode = 'OptimizedSuffix'
            $s.OptimizedSuffix = '.optimized'
            $s.HistoryPath = $histFile
            $s.HistoryEnabled = $true

            $out = Invoke-FoOutputMode -SourceFile $opt -TargetPath $orig -Settings $s
            $result = [PSCustomObject]@{
                Path         = $orig
                OriginalSize = 21
                FinalSize    = 1
                OutputPath   = $out.OptimizedPath
                BackupPath   = $null
                OutputMode   = 'OptimizedSuffix'
            }
            Add-FoHistoryEntry -Result $result -Settings $s

            (Test-Path -LiteralPath $out.OptimizedPath) | Should -Be $true
            (Get-Content -LiteralPath $orig -Raw) | Should -Be 'original-long-content'

            Undo-FoOptimization -Last 1 -HistoryPath $histFile | Out-Null
            (Test-Path -LiteralPath $out.OptimizedPath) | Should -Be $false
            (Get-Content -LiteralPath $orig -Raw) | Should -Be 'original-long-content'
        }
        finally {
            Remove-Item -LiteralPath $histDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $opt -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Marks Replace mode entries as not reversible' {
        $histDir = Join-Path $env:TEMP "FoHistReplace_$(Get-Random)"
        $histFile = Join-Path $histDir 'history.json'
        $workDir = Join-Path $histDir 'work'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $orig = Join-Path $workDir 'doc.txt'
        $opt = Join-Path $env:TEMP "fo_opt_replace_$(Get-Random).txt"
        Set-Content -LiteralPath $orig -Value 'original-long-content' -NoNewline
        Set-Content -LiteralPath $opt -Value 'x' -NoNewline

        try {
            $s = Get-FoConfig
            $s.OutputMode = 'Replace'
            $s.HistoryPath = $histFile
            $s.HistoryEnabled = $true

            Invoke-FoOutputMode -SourceFile $opt -TargetPath $orig -Settings $s | Out-Null
            $result = [PSCustomObject]@{
                Path         = $orig
                OriginalSize = 21
                FinalSize    = 1
                OutputPath   = $orig
                BackupPath   = $null
                OutputMode   = 'Replace'
            }
            Add-FoHistoryEntry -Result $result -Settings $s

            $undo = @(Undo-FoOptimization -Last 1 -HistoryPath $histFile)
            $undo.Count | Should -Be 1
            $undo[0].Status | Should -Be 'NotReversible'
        }
        finally {
            Remove-Item -LiteralPath $histDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $opt -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Optimize-FoFile history E2E' -Tag Unit {
    BeforeAll {
        if (-not (Get-Module -Name FileOptimizer)) {
            Import-Module (Join-Path (Get-FoTestModuleRoot) 'FileOptimizer.psd1') -Force
        }
    }

    It 'Records history through Optimize-FoFile and restores via undo' {
        $workDir = Join-Path $TestDrive 'e2e-history'
        $bakRoot = Join-Path $workDir 'backups'
        $histFile = Join-Path $workDir 'history.json'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $png = Join-Path $workDir 'sample.png'
        $opt = Join-Path $env:TEMP "fo_e2e_opt_$(Get-Random).png"
        New-FoTestPng -Path $png
        Set-Content -LiteralPath $opt -Value 'x' -NoNewline

        try {
            $env:FO_TEST_OPT = $opt
            $env:FO_TEST_BAK = $bakRoot
            $env:FO_TEST_HIST = $histFile
            $env:FO_TEST_PNG = $png

            InModuleScope FileOptimizer {
                Mock Invoke-FoPluginChain {
                    param($Path, $Settings)

                    $origSize = (Get-Item -LiteralPath $Path).Length
                    $out = Invoke-FoOutputMode -SourceFile $env:FO_TEST_OPT -TargetPath $Path -Settings $Settings
                    return [PSCustomObject]@{
                        Path         = $Path
                        Status       = 'Optimized'
                        OriginalSize = $origSize
                        FinalSize    = (Get-Item -LiteralPath $Path).Length
                        PercentSaved = 50
                        OutputPath   = $out.OptimizedPath
                        BackupPath   = $out.BackupPath
                        OutputMode   = $Settings.OutputMode
                    }
                }

                $results = @(Optimize-FoFile -Path $env:FO_TEST_PNG -OutputMode TempMove -TempBackupPath $env:FO_TEST_BAK `
                    -HistoryPath $env:FO_TEST_HIST -HistoryEnabled:$true -Confirm:$false)
                $results[0].Status | Should -Be 'Optimized'

                $hist = @(Get-FoHistory -HistoryPath $env:FO_TEST_HIST -Format Object -Last 1)
                $hist.Count | Should -Be 1
                $hist[0].TargetPath | Should -Be $env:FO_TEST_PNG
                $hist[0].ReversalStatus | Should -Be 'Pending'

                $undo = @(Undo-FoOptimization -Last 1 -HistoryPath $env:FO_TEST_HIST)
                $undo[0].Status | Should -Be 'Reversed'
                (Get-Item -LiteralPath $env:FO_TEST_PNG).Length | Should -BeGreaterThan (Get-Item -LiteralPath $env:FO_TEST_OPT).Length
            }
        }
        finally {
            Remove-Item Env:FO_TEST_OPT, Env:FO_TEST_BAK, Env:FO_TEST_HIST, Env:FO_TEST_PNG -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $opt -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Missing tools policy' -Tag Unit {
    It 'Fails hard when the plugin bundle is not installed' {
        $png = Join-Path $env:TEMP "fo_miss_bundle_$(Get-Random).png"
        $emptyPlugins = Join-Path $TestDrive 'empty-plugins-bundle'
        New-Item -ItemType Directory -Path $emptyPlugins -Force | Out-Null
        New-FoTestPng -Path $png
        try {
            { Optimize-FoFile -Path $png -PluginPath $emptyPlugins -PluginSearchMode PortableOnly -ErrorAction Stop } |
                Should -Throw '*Plugin bundle is not installed*'
        }
        finally {
            Remove-Item $png -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Fails hard when required tools are missing (default Error policy)' {
        $png = Join-Path $env:TEMP "fo_miss_tools_$(Get-Random).png"
        $partial = Join-Path $TestDrive 'partial-plugins-error'
        New-Item -ItemType Directory -Path $partial -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $partial 'oxipng.exe'), [byte[]](1))
        $manifest = New-FoPluginBundleManifestObject -PluginDirectory $partial -BundleVersion (Get-FoMinimumPluginBundleVersion) -Architecture 64
        Save-FoPluginBundleManifest -Manifest $manifest -Path (Join-Path $partial (Get-FoPluginBundleManifestFileName))
        New-FoTestPng -Path $png
        try {
            { Optimize-FoFile -Path $png -PluginPath $partial -PluginSearchMode PortableOnly -ErrorAction Stop } |
                Should -Throw '*Required plugin tool*'
        }
        finally {
            Remove-Item $png -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Skips individual tools when MissingToolsPolicy is SkipTool' {
        $png = Join-Path $env:TEMP "fo_miss_skiptool_$(Get-Random).png"
        $partial = Join-Path $TestDrive 'partial-plugins-skiptool'
        New-Item -ItemType Directory -Path $partial -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $partial 'oxipng.exe'), [byte[]](1))
        $manifest = New-FoPluginBundleManifestObject -PluginDirectory $partial -BundleVersion (Get-FoMinimumPluginBundleVersion) -Architecture 64
        Save-FoPluginBundleManifest -Manifest $manifest -Path (Join-Path $partial (Get-FoPluginBundleManifestFileName))
        New-FoTestPng -Path $png
        try {
            $r = Optimize-FoFile -Path $png -PluginPath $partial -PluginSearchMode PortableOnly -MissingToolsPolicy SkipTool -ErrorAction Stop
            $r[0].Status | Should -BeIn @('Unchanged', 'Optimized')
        }
        finally {
            Remove-Item $png -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Skips the file when MissingToolsPolicy is SkipFile' {
        $png = Join-Path $env:TEMP "fo_miss_skipfile_$(Get-Random).png"
        $partial = Join-Path $TestDrive 'partial-plugins-skipfile'
        New-Item -ItemType Directory -Path $partial -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $partial 'oxipng.exe'), [byte[]](1))
        $manifest = New-FoPluginBundleManifestObject -PluginDirectory $partial -BundleVersion (Get-FoMinimumPluginBundleVersion) -Architecture 64
        Save-FoPluginBundleManifest -Manifest $manifest -Path (Join-Path $partial (Get-FoPluginBundleManifestFileName))
        New-FoTestPng -Path $png
        try {
            $r = Optimize-FoFile -Path $png -PluginPath $partial -PluginSearchMode PortableOnly -MissingToolsPolicy SkipFile
            $r[0].Status | Should -Be 'Skipped'
            $r[0].Reason | Should -Be 'MissingTools'
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

    It 'Continues batch when -ContinueOnError is set even with MissingToolsPolicy Error' {
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

            $results = @(Optimize-FoFile -Path @($BadPath, $GoodPath) -ContinueOnError -MissingToolsPolicy Error -Confirm:$false)
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
            # Analyzer does not see Mock scriptblock usage of these parameters.
            $null = $GoodPath, $BadPath

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
            ($result.ExecutablesNeeded -contains 'truepng.exe') | Should -Be $true
            ($result.ExecutablesNeeded -contains 'pngout.exe') | Should -Be $true
            ($result.ExecutablesNeeded -contains 'defluff.exe') | Should -Be $true
            ($result.ExecutablesNeeded -contains 'gswin64c.exe') | Should -Be $true
        }
        finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Uses a PNG-unique extension for pipeline inventory (not shared .ico)' {
        InModuleScope FileOptimizer {
            $script:FoPipelineGroupPrimaryExtensions = $null
            $primary = Get-FoPipelineGroupPrimaryExtensions
            $primary['PNG'] | Should -Be '.png'
            $primary['ICO'] | Should -BeIn @('.cur', '.ico', '.spl')
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

    It 'Collects executables from pipeline step objects instead of regex scraping' {
        InModuleScope FileOptimizer {
            $x64 = Get-FoRequiredPluginExecutables -Architecture 64
            $x64.Count | Should -BeGreaterThan 50
            ($x64 -contains 'oxipng.exe') | Should -Be $true
            ($x64 -contains 'defluff.exe') | Should -Be $true
            ($x64 -contains 'gswin64c.exe') | Should -Be $true
            ($x64 -contains 'magick.exe') | Should -Be $true

            $declared = Get-FoPipelineDeclaredExecutables -Architecture 64
            @($declared | Sort-Object) | Should -Be @($x64 | Sort-Object)
        }
    }

    It 'Warns when pipeline inventory enumeration fails' {
        InModuleScope FileOptimizer {
            $script:inventoryWarn = $null
            Mock Write-Warning { param($Message) $script:inventoryWarn = $Message }

            function script:Get-FoInventoryTestThrowPipeline {
                param([hashtable]$Context)
                $null = $Context
                throw 'inventory-test-failure'
            }

            try {
                Get-FoPipelineDeclaredExecutables | Out-Null
                $script:inventoryWarn | Should -Match 'Get-FoInventoryTestThrowPipeline'
                $script:inventoryWarn | Should -Match 'inventory-test-failure'
            }
            finally {
                Remove-Item -Path Function:\Get-FoInventoryTestThrowPipeline -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'Get-FoNativeHandlerRegistry' -Tag Unit {
    It 'Maps handler steps to registry executables' {
        InModuleScope FileOptimizer {
            $registry = Get-FoNativeHandlerRegistry
            foreach ($name in $registry.Keys) {
                $step = [PSCustomObject]@{ Handler = $name }
                @(Get-FoStepRequiredExecutables -Step $step) | Should -Be @($registry[$name].Executables)
            }
        }
    }

    It 'Dispatches every registered handler' {
        InModuleScope FileOptimizer {
            $registry = Get-FoNativeHandlerRegistry

            Mock Resolve-FoPluginExecutable { [PSCustomObject]@{ Found = $true; Path = 'C:\tools\mock.exe' } }
            Mock Invoke-FoDefluffPipe { 0 }
            Mock Invoke-FoGzipRecompress { 0 }
            Mock Invoke-FoJsMinPipe { 0 }
            Mock Invoke-FoSqliteOptimize { 0 }

            foreach ($name in $registry.Keys) {
                Invoke-FoNativeHandler -HandlerName $name -InputPath 'C:\in' -OutputPath 'C:\out' -SearchMode PortableOnly -PluginPath 'C:\tools' |
                    Should -Be 0
            }
        }
    }

    It 'Returns null for unknown handlers' {
        InModuleScope FileOptimizer {
            Invoke-FoNativeHandler -HandlerName 'Nonexistent' -InputPath 'C:\in' -OutputPath 'C:\out' |
                Should -Be $null
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
