param(
    [string[]]$Path,
    [int]$Last,
    [string]$HistoryPath,
    [string]$ConfigPath,
    [switch]$WhatIf
)

$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

$settings = Get-FoConfig -ConfigPath $ConfigPath
$hist = if ($HistoryPath) { $HistoryPath } else { $settings.HistoryPath }

if ($Path) {
    Undo-FoOptimization -Path $Path -HistoryPath $hist -WhatIf:$WhatIf
}
elseif ($Last -gt 0) {
    Undo-FoOptimization -Last $Last -HistoryPath $hist -WhatIf:$WhatIf
}
else {
    Write-Error 'Specify -Path or -Last.'
}
