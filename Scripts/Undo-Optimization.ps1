param(
    [string[]]$Path,
    [int]$Last,
    [string]$HistoryPath,
    [string]$ConfigPath,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

try {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

    $settings = Get-FoConfig -ConfigPath $ConfigPath
    $hist = if ($HistoryPath) { $HistoryPath } else { $settings.HistoryPath }

    if ($Path) {
        $results = @(Undo-FoOptimization -Path $Path -HistoryPath $hist -WhatIf:$WhatIf)
    }
    elseif ($Last -gt 0) {
        $results = @(Undo-FoOptimization -Last $Last -HistoryPath $hist -WhatIf:$WhatIf)
    }
    else {
        [Console]::Error.WriteLine('Specify -Path or -Last.')
        exit 1
    }

    if ($results | Where-Object { $_.Status -eq 'Error' }) {
        exit 1
    }

    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
