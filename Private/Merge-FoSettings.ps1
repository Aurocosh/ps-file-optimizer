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

function Merge-FoConfigHashtableIntoSettings {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Settings,
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    foreach ($key in $Config.Keys) {
        if ($key -eq 'SkipMissingTools') { continue }
        $Settings[$key] = $Config[$key]
    }

    # Legacy config key: map only when MissingToolsPolicy was not set in this config object.
    if ($Config.ContainsKey('SkipMissingTools') -and $null -ne $Config['SkipMissingTools'] -and
        -not ($Config.ContainsKey('MissingToolsPolicy') -and -not [string]::IsNullOrWhiteSpace([string]$Config['MissingToolsPolicy']))) {
        $Settings.MissingToolsPolicy = if ([bool]$Config['SkipMissingTools']) { 'SkipFile' } else { 'Error' }
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
        Merge-FoConfigHashtableIntoSettings -Settings $settings -Config $globalCfg
    }

    if ($BoundParameters.ConfigPath -and (Test-Path -LiteralPath $BoundParameters.ConfigPath)) {
        $localCfg = Import-FoJsonFile -Path $BoundParameters.ConfigPath
        Merge-FoConfigHashtableIntoSettings -Settings $settings -Config $localCfg
    }

    $skipKeys = @('ConfigPath', 'InitializeConfig', 'Force', 'ShowHistory', 'HistoryFormat', 'ShowConfig', 'Path', 'WhatIf', 'Confirm', 'Verbose', 'Debug', 'AcknowledgeOutdatedPlugins', 'ShowProgress', 'Recurse', 'ContinueOnError', 'SkipMissingTools', 'Last', 'LastBatches')
    foreach ($key in $BoundParameters.Keys) {
        if ($key -in $skipKeys) { continue }
        if ($null -ne $BoundParameters[$key]) {
            $settings[$key] = $BoundParameters[$key]
        }
    }

    # Legacy -SkipMissingTools switch on cmdlets (MissingToolsPolicy bound param wins).
    if (-not ($BoundParameters.ContainsKey('MissingToolsPolicy') -and $null -ne $BoundParameters['MissingToolsPolicy'])) {
        if ($BoundParameters.ContainsKey('SkipMissingTools') -and $null -ne $BoundParameters['SkipMissingTools']) {
            $settings.MissingToolsPolicy = if ([bool]$BoundParameters['SkipMissingTools']) { 'SkipFile' } else { 'Error' }
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$settings.MissingToolsPolicy)) {
        $settings.MissingToolsPolicy = 'Error'
    }
    $policy = [string]$settings.MissingToolsPolicy
    if ($policy -notin @('Error', 'SkipTool', 'SkipFile')) {
        throw [ArgumentException]::new("MissingToolsPolicy must be Error, SkipTool, or SkipFile (got '$policy').")
    }
    $settings.MissingToolsPolicy = $policy
    if ($settings.ContainsKey('SkipMissingTools')) {
        $null = $settings.Remove('SkipMissingTools')
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

    if ([string]::IsNullOrWhiteSpace([string]$settings.ReportVerbosity)) {
        $settings.ReportVerbosity = 'Standard'
    }
    $verbosity = [string]$settings.ReportVerbosity
    if ($verbosity -notin @('Compact', 'Standard', 'Verbose')) {
        throw [ArgumentException]::new("ReportVerbosity must be Compact, Standard, or Verbose (got '$verbosity').")
    }
    $settings.ReportVerbosity = $verbosity

    if ([string]::IsNullOrWhiteSpace([string]$settings.SizeDisplayUnit)) {
        $settings.SizeDisplayUnit = 'Auto'
    }
    $sizeUnit = [string]$settings.SizeDisplayUnit
    if ($sizeUnit -notin @('Auto', 'Bytes', 'KB', 'MB', 'GB')) {
        throw [ArgumentException]::new("SizeDisplayUnit must be Auto, Bytes, KB, MB, or GB (got '$sizeUnit').")
    }
    $settings.SizeDisplayUnit = $sizeUnit

    Test-FoSafeSuffix -Value $settings.BackupSuffix -SettingName 'BackupSuffix'
    Test-FoSafeSuffix -Value $settings.OptimizedSuffix -SettingName 'OptimizedSuffix'

    if ($null -ne $settings.Level) {
        $settings.Level = [Math]::Max(0, [Math]::Min(9, [int]$settings.Level))
    }

    return $settings
}
