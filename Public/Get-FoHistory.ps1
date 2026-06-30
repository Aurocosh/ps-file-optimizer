function Get-FoHistory {
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

    $data = Get-FoHistoryData -HistoryPath $path
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
