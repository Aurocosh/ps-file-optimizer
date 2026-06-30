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

    $lines = @(
        'FileOptimizer optimization report'
        "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "Level: $($Settings.Level) | OutputMode: $($Settings.OutputMode) | PluginSearchMode: $($Settings.PluginSearchMode)"
        '---'
    )

    $lvl = $Settings.ReportLogLevel
    foreach ($r in $Results) {
        switch ($r.Status) {
            'Optimized' {
                $lines += "Optimized $($r.Path): $(Format-FoFileSize $r.OriginalSize -IncludeBytes) -> $(Format-FoFileSize $r.FinalSize -IncludeBytes) (-$($r.PercentSaved)%)"
                if ($lvl -ge 2 -and $r.Steps) {
                    foreach ($s in $r.Steps) {
                        if ($s.Accepted) {
                            $pct = if ($s.SizeBefore -gt 0) { [math]::Round((1 - $s.SizeAfter / $s.SizeBefore) * 100, 1) } else { 0 }
                            $lines += "  $($s.Step): $(Format-FoFileSize $s.SizeBefore -IncludeBytes) -> $(Format-FoFileSize $s.SizeAfter -IncludeBytes) (-$pct%)"
                        }
                    }
                }
            }
            'Unchanged' { $lines += "Unchanged $($r.Path): $(Format-FoFileSize $r.OriginalSize)" }
            'Skipped'   { $lines += "Skipped $($r.Path): $($r.Reason) $(if ($r.Missing) { '(' + ($r.Missing -join ', ') + ')' })" }
            default     { $lines += "$($r.Status) $($r.Path)" }
        }
    }

    $opt = @($Results | Where-Object Status -eq 'Optimized').Count
    $saved = ($Results | Where-Object { $_.BytesSaved -gt 0 } | Measure-Object -Property BytesSaved -Sum).Sum
    $lines += '---'
    $savedTotal = if ($null -ne $saved) { $saved } else { 0 }
    $lines += "Summary: $($Results.Count) files | $opt optimized | $(@($Results | Where-Object Status -eq 'Unchanged').Count) unchanged | $(@($Results | Where-Object Status -eq 'Skipped').Count) skipped | saved $(Format-FoFileSize $savedTotal)"

    Set-Content -LiteralPath $ReportPath -Value ($lines -join "`n") -Encoding UTF8
}
