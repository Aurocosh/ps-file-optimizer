function Get-FoHistoryRestorePath {
    param($Entry)

    if ($Entry.TargetPath) { return $Entry.TargetPath }
    return $Entry.OriginalPath
}

function Invoke-FoRollback {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        $Entry
    )

    $restorePath = Get-FoHistoryRestorePath -Entry $Entry
    $mode = $Entry.OutputMode
    $reversible = $mode -in @('TempMove', 'BackupSuffix', 'BackupMove', 'OptimizedSuffix')

    if ($mode -eq 'Replace' -or (-not $reversible -and $mode -ne 'OptimizedSuffix')) {
        return @{ Success = $false; Status = 'NotReversible'; Message = "OutputMode $mode is not reversible." }
    }

    if ($mode -eq 'OptimizedSuffix') {
        $deleteTarget = $Entry.OptimizedPath
        if (-not $PSCmdlet.ShouldProcess($deleteTarget, 'Remove optimized sibling')) {
            return @{ Success = $true; Status = 'WhatIf'; Message = "Would delete $deleteTarget" }
        }
        if ($Entry.OptimizedPath -and (Test-Path -LiteralPath $Entry.OptimizedPath) -and $Entry.OptimizedPath -ne $restorePath) {
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

    if (-not $PSCmdlet.ShouldProcess($restorePath, "Restore backup $($Entry.BackupPath)")) {
        return @{ Success = $true; Status = 'WhatIf'; Message = "Would restore $($Entry.BackupPath) -> $restorePath" }
    }

    try {
        if ($Entry.OptimizedPath -and (Test-Path -LiteralPath $Entry.OptimizedPath)) {
            Remove-Item -LiteralPath $Entry.OptimizedPath -Force
        }
        $destDir = Split-Path -Parent $restorePath
        if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Move-Item -LiteralPath $Entry.BackupPath -Destination $restorePath -Force
        return @{ Success = $true; Status = 'Reversed'; Message = 'Restored original file.' }
    }
    catch {
        return @{ Success = $false; Status = 'Error'; Message = $_.Exception.Message }
    }
}
