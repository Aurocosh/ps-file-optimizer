function Get-FoHistoryData {
    param([string]$HistoryPath)
    $path = if ($HistoryPath) { $HistoryPath } else { Get-FoDefaultHistoryPath }
    if (-not (Test-Path -LiteralPath $path)) {
        return @{ Version = 1; Entries = @() }
    }
    return Import-FoDataFile -Path $path
}

function Save-FoHistoryData {
    param(
        [hashtable]$Data,
        [string]$HistoryPath
    )
    $path = if ($HistoryPath) { $HistoryPath } else { Get-FoDefaultHistoryPath }
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $lines = @(
        '@{'
        '    Version = 1'
        '    Entries = @('
    )
    foreach ($e in $Data.Entries) {
        $lines += '        @{'
        foreach ($k in @('Id','Timestamp','OriginalPath','OriginalSize','FinalSize','OptimizedPath','BackupPath','OutputMode','ReversalStatus','ErrorMessage')) {
            $v = $e[$k]
            if ($null -eq $v) { $lines += "            $k = `$null" }
            elseif ($v -is [string]) { $lines += "            $k = '$($v -replace "'", "''")'" }
            else { $lines += "            $k = $v" }
        }
        $lines += '        }'
    }
    $lines += '    )'
    $lines += '}'
    $tmp = "$path.tmp"
    Set-Content -LiteralPath $tmp -Value ($lines -join "`n") -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $path -Force
}

function Add-FoHistoryEntry {
    param(
        $Result,
        [hashtable]$Settings
    )

    if (-not $Settings.HistoryEnabled) { return }

    $data = Get-FoHistoryData -HistoryPath $Settings.HistoryPath
    $id = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + ('{0:D3}' -f ($data.Entries.Count + 1))
    $entry = @{
        Id             = $id
        Timestamp      = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        OriginalPath   = $Result.Path
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

function Update-FoHistoryEntry {
    param(
        [string]$Id,
        [string]$ReversalStatus,
        [string]$ErrorMessage,
        [string]$HistoryPath
    )

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
