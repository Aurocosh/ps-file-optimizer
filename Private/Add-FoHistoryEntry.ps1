function Get-FoHistoryMutexName {
    param([string]$HistoryPath)

    $path = if ($HistoryPath) { $HistoryPath } else { Get-FoDefaultHistoryPath }
    $fullPath = [System.IO.Path]::GetFullPath($path).ToLowerInvariant()
    $hash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash(
            [System.Text.Encoding]::UTF8.GetBytes($fullPath)
        )
    ).Replace('-', '')
    return "Local\FoHistory_$hash"
}

function Invoke-FoHistoryFileLock {
    param(
        [string]$HistoryPath,
        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    $mutex = New-Object System.Threading.Mutex($false, (Get-FoHistoryMutexName -HistoryPath $HistoryPath))
    try {
        if (-not $mutex.WaitOne(30000)) {
            throw 'Timed out waiting for history file lock.'
        }
        return & $Action
    }
    finally {
        try { $mutex.ReleaseMutex() } catch { }
        $mutex.Dispose()
    }
}

function Get-FoHistoryData {
    param([string]$HistoryPath)
    $path = if ($HistoryPath) { $HistoryPath } else { Get-FoDefaultHistoryPath }
    if (-not (Test-Path -LiteralPath $path)) {
        return @{ Version = 1; Entries = @() }
    }
    return Import-FoJsonFile -Path $path
}

function Save-FoHistoryData {
    param(
        [hashtable]$Data,
        [string]$HistoryPath
    )
    $path = if ($HistoryPath) { $HistoryPath } else { Get-FoDefaultHistoryPath }
    Save-FoJsonFile -Path $path -Data $Data -Depth 6
}

function Add-FoHistoryEntry {
    param(
        $Result,
        [hashtable]$Settings
    )

    if (-not $Settings.HistoryEnabled) { return }

    Invoke-FoHistoryFileLock -HistoryPath $Settings.HistoryPath -Action {
        $data = Get-FoHistoryData -HistoryPath $Settings.HistoryPath
        $id = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + ('{0:D3}' -f ($data.Entries.Count + 1))
        # History entry fields:
        # - TargetPath / OriginalPath: user-visible path where the optimized file was written (undo restore destination)
        # - OptimizedPath: same as TargetPath for in-place modes; sibling path for OptimizedSuffix
        # - BackupPath: location of pre-optimization bytes for reversible modes (TempMove, BackupSuffix, BackupMove)
        # - OriginalSize / FinalSize: byte sizes before and after optimization
        $targetPath = $Result.Path
        $entry = @{
            Id             = $id
            Timestamp      = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
            TargetPath     = $targetPath
            OriginalPath   = $targetPath
            OriginalSize   = $Result.OriginalSize
            FinalSize      = $Result.FinalSize
            OptimizedPath  = $Result.OutputPath
            BackupPath     = $Result.BackupPath
            OutputMode     = $Result.OutputMode
            ReversalStatus = 'Pending'
            ErrorMessage   = $null
        }
        $data.Entries = @($data.Entries) + @($entry)
        Save-FoHistoryData -Data $data -HistoryPath $Settings.HistoryPath
        $Result | Add-Member -NotePropertyName HistoryId -NotePropertyValue $id -Force
    }
}

function Update-FoHistoryEntry {
    param(
        [string]$Id,
        [string]$ReversalStatus,
        [string]$ErrorMessage,
        [string]$HistoryPath
    )

    Invoke-FoHistoryFileLock -HistoryPath $HistoryPath -Action {
        $data = Get-FoHistoryData -HistoryPath $HistoryPath
        $updated = @()
        foreach ($e in $data.Entries) {
            if ($e.Id -eq $Id) {
                $e.ReversalStatus = $ReversalStatus
                $e.ErrorMessage = $ErrorMessage
            }
            $updated += $e
        }
        $data.Entries = $updated
        Save-FoHistoryData -Data $data -HistoryPath $HistoryPath
    }
}
