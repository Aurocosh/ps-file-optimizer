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
