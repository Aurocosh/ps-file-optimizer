$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

. "$PSScriptRoot\TestHelpers.ps1"

Describe 'Format-FoFileSize' {
    It 'Formats bytes' {
        Format-FoFileSize -Bytes 1024 | Should Be '1.0 KB'
    }
}

Describe 'Merge-FoSettings' {
    It 'Explicit parameter overrides defaults' {
        $s = Merge-FoSettings -BoundParameters @{ Level = 9 }
        $s.Level | Should Be 9
        $s.OutputMode | Should Be 'TempMove'
    }
}

Describe 'Config merge' {
    It 'Bound Level overrides defaults via Merge-FoSettings' {
        $s = Merge-FoSettings -BoundParameters @{ Level = 7 }
        $s.Level | Should Be 7
    }
}

Describe 'Resolve-FoPluginExecutable' {
    It 'Finds portable plugin when present' {
        $pluginPath = 'D:\Projects\FileOptimizerAnalisys\FileOptimizerFull\Plugins64'
        if (-not (Test-Path $pluginPath)) {
            Set-TestInconclusive 'Plugins64 not present'
            return
        }
        $r = Resolve-FoPluginExecutable -Name 'oxipng.exe' -SearchMode PortableOnly -PluginPath $pluginPath
        $r.Found | Should Be $true
    }

    It 'PortableOnly returns not found for bad path' {
        $r = Resolve-FoPluginExecutable -Name 'nonexistent_fo_tool_12345.exe' -SearchMode PortableOnly -PluginPath 'C:\nonexistent'
        $r.Found | Should Be $false
    }
}

Describe 'Get-FoPipeline PNG' {
    It 'Returns multiple steps' {
        $png = Join-Path $env:TEMP "fo_pipe_$(Get-Random).png"
        New-FoTestPng -Path $png
        try {
            $ctx = New-FoFileContext -InputFile $png -Settings (Get-FoConfig)
            $steps = Get-FoPipeline -GroupName PNG -Context $ctx
            ($steps.Count -gt 5) | Should Be $true
        }
        finally {
            Remove-Item $png -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Pipeline WhatIf snapshot' {
    It 'PNG pipeline reports many steps' {
        $png = Join-Path $env:TEMP "fo_whatif_$(Get-Random).png"
        New-FoTestPng -Path $png
        try {
            $r = Optimize-FoFile -Path $png -PluginPath 'C:\nonexistent' -PluginSearchMode PortableOnly -WhatIf
            $r[0].Status | Should Be 'WhatIf'
            ($r[0].Steps.Count -gt 5) | Should Be $true
        }
        finally {
            Remove-Item $png -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Invoke-FoOutputMode TempMove' {
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
            ($null -ne $r.BackupPath) | Should Be $true
            (Test-Path -LiteralPath $orig) | Should Be $true
        }
        finally {
            Pop-Location
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $opt -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'History and rollback' {
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
            $hist.Count | Should Be 1
            $hist[0].ReversalStatus | Should Be 'Pending'

            $undo = @(Undo-FoOptimization -Last 1 -HistoryPath $histFile)
            ($undo.Count -gt 0) | Should Be $true
            (Get-Content -LiteralPath $orig -Raw) | Should Be 'original-long-content'

            $hist2 = @(Get-FoHistory -Last 1 -HistoryPath $histFile -Format Object)
            $hist2[0].ReversalStatus | Should Be 'Reversed'
        }
        finally {
            Pop-Location
            Remove-Item -LiteralPath $histDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $opt -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Missing tools policy' {
    It 'Throws when tools missing' {
        $png = Join-Path $env:TEMP "fo_miss_$(Get-Random).png"
        New-FoTestPng -Path $png
        try {
            { Optimize-FoFile -Path $png -PluginPath 'C:\nonexistent_plugins' -PluginSearchMode PortableOnly -ErrorAction Stop } | Should Throw
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
            $r[0].Status | Should Be 'Skipped'
        }
        finally {
            Remove-Item $png -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Extension map' {
    It 'Loads extension map with many entries' {
        $mapPath = Join-Path $moduleRoot 'Data\ExtensionMap.psd1'
        $map = Import-FoDataFile -Path $mapPath
        ($map.Keys.Count -ge 370) | Should Be $true
    }
}
