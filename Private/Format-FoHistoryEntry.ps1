function Format-FoHistoryEntry {
    param(
        $Entry,
        [ValidateSet('Summary', 'Detailed')]
        [string]$Format = 'Summary'
    )

    if ($Format -eq 'Detailed') {
        $pct = if ($Entry.OriginalSize -gt 0) {
            [math]::Round((1 - $Entry.FinalSize / $Entry.OriginalSize) * 100, 1)
        }
        else { 0 }
        return @(
            "Id:             $($Entry.Id)"
            "Timestamp:      $($Entry.Timestamp)"
            "Status:         $($Entry.ReversalStatus)"
            "OutputMode:     $($Entry.OutputMode)"
            "OriginalPath:   $($Entry.OriginalPath)"
            "OriginalSize:   $(Format-FoFileSize $Entry.OriginalSize -IncludeBytes)"
            "FinalSize:      $(Format-FoFileSize $Entry.FinalSize -IncludeBytes) (-$pct%)"
            "OptimizedPath:  $($Entry.OptimizedPath)"
            "BackupPath:     $($Entry.BackupPath)"
            '---'
        ) -join "`n"
    }

    $pct = if ($Entry.OriginalSize -gt 0) {
        [math]::Round((1 - $Entry.FinalSize / $Entry.OriginalSize) * 100, 1)
    }
    else { 0 }
    return ('[{0}] {1}  {2,-14} {3,-10} {4}  {5} -> {6} (-{7}%)' -f `
        $Entry.Id, $Entry.Timestamp, $Entry.ReversalStatus, $Entry.OutputMode, $Entry.OriginalPath, `
        (Format-FoFileSize $Entry.OriginalSize), (Format-FoFileSize $Entry.FinalSize), $pct)
}
