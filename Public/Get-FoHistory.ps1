function Get-FoHistory {
    <#
    .SYNOPSIS
    Displays or returns optimization history entries.

    .DESCRIPTION
    Reads history.json and shows recent entries. Use -Format Object in scripts
    to receive structured entry objects instead of formatted text.

    History entry fields (see also Undo-FoOptimization, about_FileOptimizer):
    BatchId — shared id for one Optimize-FoFile run.
    TargetPath — where the optimized file was written (restore destination for undo).
    OriginalPath — same value as TargetPath on each entry.
    OptimizedPath — optimized output path. BackupPath — pre-optimize backup when reversible.
    ReversalStatus — Pending, Reversed, NotReversible, or Error.

    .PARAMETER Last
    Maximum number of entries to return (default 10). Ignored when -LastBatches is set.

    .PARAMETER LastBatches
    Return entries belonging to the N most recent batches (by newest entry timestamp).

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
    Get-FoHistory -LastBatches 1

    .EXAMPLE
    .\Scripts\Show-History.ps1 -Last 10

    .EXAMPLE
    $pending = Get-FoHistory -Format Object -Status Pending
    $pending | Select-Object Id, BatchId, OriginalPath
    #>
    [CmdletBinding(DefaultParameterSetName = 'Last')]
    [OutputType([object[]])]
    param(
        [Parameter(ParameterSetName = 'Last')]
        [int]$Last = 10,

        [Parameter(ParameterSetName = 'LastBatches')]
        [int]$LastBatches,

        [string]$HistoryPath,
        [ValidateSet('Summary', 'Detailed', 'Object')]
        [string]$Format = 'Summary',
        [ValidateSet('Pending', 'Reversed', 'NotReversible', 'Error')]
        [string]$Status,
        [string]$Id,
        [ValidateSet('Auto', 'Bytes', 'KB', 'MB', 'GB')]
        [string]$SizeDisplayUnit = 'Auto'
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

    $entries = @($entries | Sort-Object { $_.Timestamp } -Descending)

    if ($PSCmdlet.ParameterSetName -eq 'LastBatches') {
        if (-not ($LastBatches -gt 0)) {
            throw '-LastBatches must be greater than zero.'
        }
        $batchKeys = [System.Collections.Generic.List[string]]::new()
        foreach ($e in $entries) {
            $key = if ($e.BatchId) { [string]$e.BatchId } else { "entry:$($e.Id)" }
            if (-not ($batchKeys -contains $key)) {
                $batchKeys.Add($key)
            }
            if ($batchKeys.Count -ge $LastBatches) { break }
        }
        $selected = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($k in $batchKeys) { [void]$selected.Add($k) }
        $entries = @($entries | Where-Object {
            $key = if ($_.BatchId) { [string]$_.BatchId } else { "entry:$($_.Id)" }
            $selected.Contains($key)
        })
    }
    else {
        $entries = @($entries | Select-Object -First $Last)
    }

    if ($Format -eq 'Object') { return $entries }

    foreach ($e in $entries) {
        if ($Format -eq 'Detailed') {
            Write-Host (Format-FoHistoryEntry -Entry $e -Format Detailed -Unit $SizeDisplayUnit)
        }
        else {
            Write-Host (Format-FoHistoryEntry -Entry $e -Format Summary -Unit $SizeDisplayUnit)
        }
    }
}
