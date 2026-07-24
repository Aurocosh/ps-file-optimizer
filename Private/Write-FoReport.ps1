function Write-FoReport {
    param(
        [array]$Results,
        [hashtable]$Settings,
        [string]$ReportPath
    )

    if (-not $ReportPath) { return }

    $dir = Split-Path -Parent $ReportPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $unit = Get-FoSizeDisplayUnit -Settings $Settings
    $verbosity = Get-FoReportVerbosity -Settings $Settings
    $lvl = $Settings.ReportLogLevel

    $lines = @(
        'FileOptimizer optimization report'
        "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "Level: $($Settings.Level) | OutputMode: $($Settings.OutputMode) | PluginSearchMode: $($Settings.PluginSearchMode) | ReportVerbosity: $verbosity | SizeDisplayUnit: $unit"
        '---'
    )

    switch ($verbosity) {
        'Compact' {
            foreach ($r in $Results) {
                $outputPath = if ($r.OutputPath) { $r.OutputPath } else { $r.Path }
                switch ($r.Status) {
                    'Optimized' {
                        $lines += '{0}: {1}' -f $outputPath, (Format-FoSizeChange -OriginalSize $r.OriginalSize -FinalSize $r.FinalSize -Unit $unit)
                    }
                    'Unchanged' {
                        $lines += '{0}: {1} (unchanged)' -f $outputPath, (Format-FoFileSize -Bytes $r.OriginalSize -Unit $unit)
                    }
                    'Skipped' {
                        $lines += '{0}: skipped ({1})' -f $r.Path, $r.Reason
                    }
                    default {
                        $lines += '{0}: {1}' -f $r.Path, $r.Status
                    }
                }
            }
        }
        'Standard' {
            foreach ($r in $Results) {
                $row = Format-FoOptimizeResultRow -Result $r -Unit $unit
                $out = if ($row.OutputPath) { $row.OutputPath } else { '' }
                $bak = if ($row.BackupPath) { $row.BackupPath } else { '' }
                $size = if ($row.Size) { $row.Size } else { '' }
                $mode = if ($row.OutputMode) { $row.OutputMode } else { '' }
                $dur = if ($row.Duration) { $row.Duration } else { '' }
                $lines += ('{0,-10} | {1} | out={2} | bak={3} | {4} | {5} | {6}' -f `
                    $row.Status, $row.OriginalPath, $out, $bak, $size, $mode, $dur)
            }
        }
        default {
            foreach ($r in $Results) {
                switch ($r.Status) {
                    'Optimized' {
                        $lines += "Optimized $($r.Path): $(Format-FoFileSize -Bytes $r.OriginalSize -Unit $unit -IncludeBytes) -> $(Format-FoFileSize -Bytes $r.FinalSize -Unit $unit -IncludeBytes) (-$($r.PercentSaved)%)"
                        if ($lvl -ge 2 -and $r.Steps) {
                            foreach ($s in $r.Steps) {
                                if ($s.Accepted) {
                                    $lines += "  $($s.Step): $(Format-FoSizeChange -OriginalSize $s.SizeBefore -FinalSize $s.SizeAfter -Unit $unit)"
                                }
                            }
                        }
                    }
                    'Unchanged' { $lines += "Unchanged $($r.Path): $(Format-FoFileSize -Bytes $r.OriginalSize -Unit $unit)" }
                    'Skipped'   { $lines += "Skipped $($r.Path): $($r.Reason) $(if ($r.Missing) { '(' + ($r.Missing -join ', ') + ')' })" }
                    default     { $lines += "$($r.Status) $($r.Path)" }
                }
            }
        }
    }

    $opt = @($Results | Where-Object Status -eq 'Optimized').Count
    $saved = ($Results | Where-Object { $_.BytesSaved -gt 0 } | Measure-Object -Property BytesSaved -Sum).Sum
    $lines += '---'
    $savedTotal = if ($null -ne $saved) { $saved } else { 0 }
    $lines += "Summary: $($Results.Count) files | $opt optimized | $(@($Results | Where-Object Status -eq 'Unchanged').Count) unchanged | $(@($Results | Where-Object Status -eq 'Skipped').Count) skipped | saved $(Format-FoFileSize -Bytes $savedTotal -Unit $unit)"

    $tmp = "$ReportPath.tmp"
    Set-Content -LiteralPath $tmp -Value ($lines -join "`n") -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $ReportPath -Force
}
