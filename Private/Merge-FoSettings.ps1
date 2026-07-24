function Test-FoSafeSuffix {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value,
        [Parameter(Mandatory)]
        [string]$SettingName
    )

    if ([string]::IsNullOrEmpty($Value)) { return }
    if ($Value -match '[\\/:]') {
        throw [ArgumentException]::new("Setting '$SettingName' must not contain path separators.")
    }
    if ($Value -match '\.\.') {
        throw [ArgumentException]::new("Setting '$SettingName' must not contain '..' segments.")
    }
}

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

    $skipKeys = @('ConfigPath', 'InitializeConfig', 'Force', 'ShowHistory', 'HistoryFormat', 'Path', 'WhatIf', 'Confirm', 'Verbose', 'Debug', 'AcknowledgeOutdatedPlugins', 'ShowProgress', 'Recurse', 'ContinueOnError')
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
    elseif (-not (Test-Path -LiteralPath $settings.PluginPath)) {
        $stalePath = $settings.PluginPath
        $fallback = Get-FoDefaultPluginPath
        if ($fallback) {
            Write-Warning "Configured PluginPath not found: '$stalePath'. Falling back to '$fallback'."
            $settings.PluginPath = $fallback
        }
        else {
            Write-Warning "Configured PluginPath not found: '$stalePath'. Install plugins with Install-FoPlugins or pass -PluginPath."
            $settings.PluginPath = $null
        }
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

    Test-FoSafeSuffix -Value $settings.BackupSuffix -SettingName 'BackupSuffix'
    Test-FoSafeSuffix -Value $settings.OptimizedSuffix -SettingName 'OptimizedSuffix'

    if ($null -ne $settings.Level) {
        $settings.Level = [Math]::Max(0, [Math]::Min(9, [int]$settings.Level))
    }

    return $settings
}
