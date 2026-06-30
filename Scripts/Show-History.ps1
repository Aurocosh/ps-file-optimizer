param(
    [int]$Last = 10,
    [string]$HistoryPath,
    [string]$ConfigPath,
    [ValidateSet('Summary', 'Detailed', 'Object')]
    [string]$Format = 'Summary',
    [ValidateSet('Pending', 'Reversed', 'NotReversible', 'Error')]
    [string]$Status
)

$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

$settings = Get-FoConfig -ConfigPath $ConfigPath
$hist = if ($HistoryPath) { $HistoryPath } else { $settings.HistoryPath }

Get-FoHistory -Last $Last -HistoryPath $hist -Format $Format -Status $Status
