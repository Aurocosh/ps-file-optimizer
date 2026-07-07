function Merge-FoSettings {
    [CmdletBinding()]
    param(
        [hashtable]$BoundParameters = @{}
    )

    $settings = Get-FoModuleDefaults
    $globalPath = Get-FoGlobalConfigPath
    if (Test-Path -LiteralPath $globalPath) {
        $globalCfg = Import-FoJsonFile -Path $globalPath
        foreach ($key in $globalCfg.Keys) {
            $settings[$key] = $globalCfg[$key]
        }
    }

    if ($BoundParameters.ConfigPath -and (Test-Path -LiteralPath $BoundParameters.ConfigPath)) {
        $localCfg = Import-FoJsonFile -Path $BoundParameters.ConfigPath
        foreach ($key in $localCfg.Keys) {
            $settings[$key] = $localCfg[$key]
        }
    }

    $skipKeys = @('ConfigPath', 'InitializeConfig', 'Force', 'ShowHistory', 'HistoryFormat', 'Path', 'WhatIf', 'Confirm', 'Verbose', 'Debug')
    foreach ($key in $BoundParameters.Keys) {
        if ($key -in $skipKeys) { continue }
        if ($null -ne $BoundParameters[$key]) {
            $settings[$key] = $BoundParameters[$key]
        }
    }

    if ($PSBoundParameters.ContainsKey('Verbose') -and $VerbosePreference -ne 'SilentlyContinue') {
        if ($settings.LogLevel -lt 2) { $settings.LogLevel = 2 }
    }
    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Debug')) {
        if ($settings.LogLevel -lt 3) { $settings.LogLevel = 3 }
        $settings.Debug = $true
    }

    if (-not $settings.PluginPath) {
        $settings.PluginPath = Get-FoDefaultPluginPath
    }
    if (-not $settings.TempBackupPath) {
        $settings.TempBackupPath = Join-Path $env:TEMP 'FileOptimizer\backups'
    }
    if (-not $settings.HistoryPath) {
        $settings.HistoryPath = Get-FoDefaultHistoryPath
    }
    if ($null -eq $settings.ReportLogLevel) {
        $settings.ReportLogLevel = $settings.LogLevel
    }

    return $settings
}
