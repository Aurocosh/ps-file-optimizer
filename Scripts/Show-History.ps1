param(
    [int]$Last = 10,
    [int]$LastBatches,
    [string]$HistoryPath,
    [string]$ConfigPath,
    [ValidateSet('Summary', 'Detailed', 'Object')]
    [string]$Format = 'Summary',
    [ValidateSet('Pending', 'Reversed', 'NotReversible', 'Error')]
    [string]$Status,
    [ValidateSet('Auto', 'Bytes', 'KB', 'MB', 'GB')]
    [string]$SizeDisplayUnit = 'Auto'
)

$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

$settings = Get-FoConfig -ConfigPath $ConfigPath
$hist = if ($HistoryPath) { $HistoryPath } else { $settings.HistoryPath }

$params = @{
    HistoryPath      = $hist
    Format           = $Format
    SizeDisplayUnit  = $SizeDisplayUnit
}
if ($Status) { $params.Status = $Status }
if ($LastBatches -gt 0) {
    $params.LastBatches = $LastBatches
}
else {
    $params.Last = $Last
}

Get-FoHistory @params
