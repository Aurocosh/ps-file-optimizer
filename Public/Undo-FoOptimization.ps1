function Undo-FoOptimization {
    <#
    .SYNOPSIS
    Rolls back previous optimizations using the history file.

    .DESCRIPTION
    Restores originals from backups recorded when OutputMode supports reversal
    (TempMove, BackupSuffix, BackupMove, OptimizedSuffix). Updates history entry status.

    History file format (history.json):
    Each entry records one optimization. Key fields:
    - BatchId — shared id for all files from one Optimize-FoFile run (optional on older entries)
    - TargetPath — user-visible path where the optimized file was written (undo restore destination)
    - OriginalPath — same value as TargetPath on each entry
    - OptimizedPath — optimized file path (equals TargetPath for in-place modes; sibling for OptimizedSuffix)
    - BackupPath — pre-optimization bytes for reversible modes
    - OutputMode — TempMove, BackupSuffix, BackupMove, OptimizedSuffix, or Replace
    - ReversalStatus — Pending, Reversed, NotReversible, or Error

    Replace mode is not reversible. See also Get-FoHistory and about_FileOptimizer.

    .PARAMETER Path
    Roll back entries matching these original or optimized paths.

    .PARAMETER Last
    Roll back the N most recent pending history entries (files).

    .PARAMETER LastBatches
    Roll back all pending entries in the N most recent batches.

    .PARAMETER HistoryPath
    Override path to history.json. Defaults to settings or global history path.

    .EXAMPLE
    Undo-FoOptimization -Last 3

    .EXAMPLE
    Undo-FoOptimization -LastBatches 1

    .EXAMPLE
    .\Scripts\Undo-Optimization.ps1 -Path .\images\photo.png

    .EXAMPLE
    Undo-FoOptimization -Last 1 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Last')]
    [OutputType([object[]])]
    param(
        [Parameter(ParameterSetName = 'Path')]
        [string[]]$Path,

        [Parameter(ParameterSetName = 'Last')]
        [int]$Last,

        [Parameter(ParameterSetName = 'LastBatches')]
        [int]$LastBatches,

        [string]$HistoryPath
    )

    $pathHist = if ($HistoryPath) { $HistoryPath } else { Get-FoDefaultHistoryPath }

    $normalized = @()
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        if (-not $Path -or $Path.Count -eq 0) {
            throw 'Specify -Path, -Last, or -LastBatches.'
        }
        foreach ($p in $Path) {
            $resolved = Resolve-Path -LiteralPath $p -ErrorAction SilentlyContinue
            if (-not $resolved) {
                throw "Path not found: $p"
            }
            $normalized += [System.IO.Path]::GetFullPath($resolved.Path)
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Last') {
        if (-not ($Last -gt 0)) {
            throw 'Specify -Path, -Last, or -LastBatches.'
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'LastBatches') {
        if (-not ($LastBatches -gt 0)) {
            throw 'Specify -Path, -Last, or -LastBatches.'
        }
    }

    $results = [System.Collections.Generic.List[object]]::new()

    Invoke-FoHistoryFileLock -HistoryPath $pathHist -Action {
        $data = Get-FoHistoryData -HistoryPath $pathHist
        $entries = @($data.Entries | Where-Object { $_.ReversalStatus -eq 'Pending' } | Sort-Object Timestamp -Descending)

        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $entries = @($entries | Where-Object {
                $restore = Get-FoHistoryRestorePath -Entry $_
                $rp = [System.IO.Path]::GetFullPath($restore)
                $op = [System.IO.Path]::GetFullPath($_.OriginalPath)
                $opt = if ($_.OptimizedPath) { [System.IO.Path]::GetFullPath($_.OptimizedPath) } else { '' }
                ($normalized -contains $rp) -or ($normalized -contains $op) -or ($opt -and ($normalized -contains $opt))
            })
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Last') {
            $entries = @($entries | Select-Object -First $Last)
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'LastBatches') {
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

        foreach ($entry in $entries) {
            if ($WhatIfPreference) {
                $r = Invoke-FoRollback -Entry $entry -Confirm:$false
                Write-Host "WHATIF: $($r.Message)"
                continue
            }
            if ($PSCmdlet.ShouldProcess((Get-FoHistoryRestorePath -Entry $entry), 'Rollback optimization')) {
                $r = Invoke-FoRollback -Entry $entry -Confirm:$false
                foreach ($e in $data.Entries) {
                    if ($e.Id -eq $entry.Id) {
                        $e.ReversalStatus = $r.Status
                        $e.ErrorMessage = if ($r.Success) { $null } else { $r.Message }
                    }
                }
                if ($r.Success) { Write-Host $r.Message } else { Write-Warning $r.Message }
                $results.Add([PSCustomObject]@{
                        Id      = $entry.Id
                        BatchId = $entry.BatchId
                        Path    = $entry.OriginalPath
                        Status  = $r.Status
                        Message = $r.Message
                    })
            }
        }

        Save-FoHistoryData -Data $data -HistoryPath $pathHist
    }

    return @($results)
}
