function Invoke-FoRollback {
    param(
        $Entry,
        [switch]$WhatIf
    )

    $mode = $Entry.OutputMode
    $reversible = $mode -in @('TempMove', 'BackupSuffix', 'BackupMove', 'OptimizedSuffix')

    if ($mode -eq 'Replace' -or (-not $reversible -and $mode -ne 'OptimizedSuffix')) {
        return @{ Success = $false; Status = 'NotReversible'; Message = "OutputMode $mode is not reversible." }
    }

    if ($mode -eq 'OptimizedSuffix') {
        if ($WhatIf) {
            return @{ Success = $true; Status = 'WhatIf'; Message = "Would delete $($Entry.OptimizedPath)" }
        }
        if ($Entry.OptimizedPath -and (Test-Path -LiteralPath $Entry.OptimizedPath) -and $Entry.OptimizedPath -ne $Entry.OriginalPath) {
            Remove-Item -LiteralPath $Entry.OptimizedPath -Force
        }
        return @{ Success = $true; Status = 'Reversed'; Message = 'Removed optimized sibling.' }
    }

    if (-not $Entry.BackupPath) {
        return @{ Success = $false; Status = 'NotReversible'; Message = 'No backup path recorded.' }
    }
    if (-not (Test-Path -LiteralPath $Entry.BackupPath)) {
        return @{ Success = $false; Status = 'Error'; Message = "Backup missing: $($Entry.BackupPath)" }
    }

    if ($WhatIf) {
        return @{ Success = $true; Status = 'WhatIf'; Message = "Would restore $($Entry.BackupPath) -> $($Entry.OriginalPath)" }
    }

    try {
        if ($Entry.OptimizedPath -and (Test-Path -LiteralPath $Entry.OptimizedPath)) {
            Remove-Item -LiteralPath $Entry.OptimizedPath -Force
        }
        $destDir = Split-Path -Parent $Entry.OriginalPath
        if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Move-Item -LiteralPath $Entry.BackupPath -Destination $Entry.OriginalPath -Force
        return @{ Success = $true; Status = 'Reversed'; Message = 'Restored original file.' }
    }
    catch {
        return @{ Success = $false; Status = 'Error'; Message = $_.Exception.Message }
    }
}

function Undo-FoOptimization {
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
        $normalized = @($Path | ForEach-Object { [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $_ -ErrorAction SilentlyContinue).Path) })
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
