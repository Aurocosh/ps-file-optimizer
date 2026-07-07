function Undo-FoOptimization {
    <#
    .SYNOPSIS
    Rolls back previous optimizations using the history file.

    .DESCRIPTION
    Restores originals from backups recorded when OutputMode supports reversal
    (TempMove, BackupSuffix, BackupMove, OptimizedSuffix). Updates history entry status.

    .PARAMETER Path
    Roll back entries matching these original or optimized paths.

    .PARAMETER Last
    Roll back the N most recent pending history entries.

    .PARAMETER HistoryPath
    Override path to history.json. Defaults to settings or global history path.

    .EXAMPLE
    Undo-FoOptimization -Last 3

    .EXAMPLE
    .\Scripts\Undo-Optimization.ps1 -Path .\images\photo.png

    .EXAMPLE
    Undo-FoOptimization -Last 1 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$Path,
        [int]$Last,
        [string]$HistoryPath
    )

    $pathHist = if ($HistoryPath) { $HistoryPath } else { Get-FoDefaultHistoryPath }
    $data = Get-FoHistoryData -HistoryPath $pathHist
    $entries = @($data.Entries | Where-Object { $_.ReversalStatus -eq 'Pending' } | Sort-Object Timestamp -Descending)

    if ($Path) {
        $normalized = @()
        foreach ($p in $Path) {
            $resolved = Resolve-Path -LiteralPath $p -ErrorAction SilentlyContinue
            if (-not $resolved) {
                throw "Path not found: $p"
            }
            $normalized += [System.IO.Path]::GetFullPath($resolved.Path)
        }
        $entries = @($entries | Where-Object {
            $op = [System.IO.Path]::GetFullPath($_.OriginalPath)
            $opt = if ($_.OptimizedPath) { [System.IO.Path]::GetFullPath($_.OptimizedPath) } else { '' }
            ($normalized -contains $op) -or ($opt -and ($normalized -contains $opt))
        })
    }
    elseif ($Last -gt 0) {
        $entries = @($entries | Select-Object -First $Last)
    }
    else {
        throw 'Specify -Path or -Last.'
    }

    $results = @()
    foreach ($entry in $entries) {
        if ($WhatIfPreference -eq 'Continue') {
            $r = Invoke-FoRollback -Entry $entry -WhatIf
            Write-Host "WHATIF: $($r.Message)"
            continue
        }
        if ($PSCmdlet.ShouldProcess($entry.OriginalPath, 'Rollback optimization')) {
            $r = Invoke-FoRollback -Entry $entry
            Update-FoHistoryEntry -Id $entry.Id -ReversalStatus $r.Status -ErrorMessage $(if ($r.Success) { $null } else { $r.Message }) -HistoryPath $pathHist
            if ($r.Success) { Write-Host $r.Message } else { Write-Warning $r.Message }
            $results += [PSCustomObject]@{ Id = $entry.Id; Path = $entry.OriginalPath; Status = $r.Status; Message = $r.Message }
        }
    }
    return $results
}
