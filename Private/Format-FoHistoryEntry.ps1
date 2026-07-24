function Format-FoHistoryEntry {
    param(
        $Entry,
        [ValidateSet('Summary', 'Detailed')]
        [string]$Format = 'Summary',
        [ValidateSet('Auto', 'Bytes', 'KB', 'MB', 'GB')]
        [string]$Unit = 'Auto'
    )

    $batch = if ($Entry.BatchId) { $Entry.BatchId } else { '-' }

    if ($Format -eq 'Detailed') {
        $pct = if ($Entry.OriginalSize -gt 0) {
            [math]::Round((1 - $Entry.FinalSize / $Entry.OriginalSize) * 100, 1)
        }
        else { 0 }
        return @(
            "Id:             $($Entry.Id)"
            "BatchId:        $batch"
            "Timestamp:      $($Entry.Timestamp)"
            "Status:         $($Entry.ReversalStatus)"
            "OutputMode:     $($Entry.OutputMode)"
            "TargetPath:     $(if ($Entry.TargetPath) { $Entry.TargetPath } else { $Entry.OriginalPath })"
            "OriginalPath:   $($Entry.OriginalPath)"
            "OriginalSize:   $(Format-FoFileSize -Bytes $Entry.OriginalSize -Unit $Unit -IncludeBytes)"
            "FinalSize:      $(Format-FoFileSize -Bytes $Entry.FinalSize -Unit $Unit -IncludeBytes) (-$pct%)"
            "OptimizedPath:  $($Entry.OptimizedPath)"
            "BackupPath:     $($Entry.BackupPath)"
            '---'
        ) -join "`n"
    }

    return ('[{0}] batch={1} {2}  {3,-14} {4,-10} {5}  {6}' -f `
        $Entry.Id, $batch, $Entry.Timestamp, $Entry.ReversalStatus, $Entry.OutputMode, `
        $(if ($Entry.TargetPath) { $Entry.TargetPath } else { $Entry.OriginalPath }), `
        (Format-FoSizeChange -OriginalSize $Entry.OriginalSize -FinalSize $Entry.FinalSize -Unit $Unit))
}
