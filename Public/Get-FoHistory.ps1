function Get-FoHistory {
    <#
    .SYNOPSIS
    Displays or returns optimization history entries.

    .DESCRIPTION
    Reads history.json and shows recent entries. Use -Format Object in scripts
    to receive structured entry objects instead of formatted text.

    History entry fields (see also Undo-FoOptimization, about_FileOptimizer):
    TargetPath — where the optimized file was written (restore destination for undo).
    OriginalPath — same value as TargetPath on each entry.
    OptimizedPath — optimized output path. BackupPath — pre-optimize backup when reversible.
    ReversalStatus — Pending, Reversed, NotReversible, or Error.

    .PARAMETER Last
    Maximum number of entries to return (default 10).

    .PARAMETER HistoryPath
    Override path to history.json.

    .PARAMETER Format
    Summary — one line per entry (default, for CLI).
    Detailed — multi-line entry details.
    Object — return entry objects (for scripting; no host output).

    .PARAMETER Status
    Filter by ReversalStatus (Pending, Reversed, NotReversible, Error).

    .PARAMETER Id
    Return the entry with this Id only.

    .EXAMPLE
    Get-FoHistory -Last 5

    .EXAMPLE
    .\Scripts\Show-History.ps1 -Last 10

    .EXAMPLE
    $pending = Get-FoHistory -Format Object -Status Pending
    $pending | Select-Object Id, OriginalPath, BytesSaved
    #>
    [CmdletBinding()]
    param(
        [int]$Last = 10,
        [string]$HistoryPath,
        [ValidateSet('Summary', 'Detailed', 'Object')]
        [string]$Format = 'Summary',
        [ValidateSet('Pending', 'Reversed', 'NotReversible', 'Error')]
        [string]$Status,
        [string]$Id
    )

    $path = if ($HistoryPath) { $HistoryPath } else { Get-FoDefaultHistoryPath }
    if (-not (Test-Path -LiteralPath $path)) {
        if ($Format -eq 'Object') { return @() }
        Write-Host 'No history file found.'
        return
    }

    $data = Invoke-FoHistoryFileLock -HistoryPath $path -Action {
        Get-FoHistoryData -HistoryPath $path
    }
    $entries = @($data.Entries)

    if ($Id) {
        $entries = @($entries | Where-Object { $_.Id -eq $Id })
    }
    if ($Status) {
        $entries = @($entries | Where-Object { $_.ReversalStatus -eq $Status })
    }

    $entries = @($entries | Sort-Object { $_.Timestamp } -Descending | Select-Object -First $Last)

    if ($Format -eq 'Object') { return $entries }

    foreach ($e in $entries) {
        if ($Format -eq 'Detailed') {
            Write-Host (Format-FoHistoryEntry -Entry $e -Format Detailed)
        }
        else {
            Write-Host (Format-FoHistoryEntry -Entry $e -Format Summary)
        }
    }
}
