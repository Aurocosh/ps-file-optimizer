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

        Push-Location $srcDir
        try {
            $s = Get-FoConfig
            $s.OutputMode = 'TempMove'
            $s.TempBackupPath = $bakRoot
            $r = Invoke-FoOutputMode -SourceFile $opt -TargetPath $orig -Settings $s
            ($null -ne $r.BackupPath) | Should -Be $true
            (Test-Path -LiteralPath $orig) | Should -Be $true
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
        $histFile = Join-Path $histDir 'history.psd1'
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

Describe 'Extension map' -Tag Unit {
    It 'Loads extension map with many entries' {
        $mapPath = Join-Path (Get-FoTestModuleRoot) 'Data\ExtensionMap.psd1'
        $map = Import-FoDataFile -Path $mapPath
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
