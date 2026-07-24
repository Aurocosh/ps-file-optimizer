param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path,
    [string]$ConfigPath,
    [ValidateSet('Global', 'Local')]
    [string]$InitializeConfig,
    [switch]$Force,
    [nullable[int]]$Level,
    [ValidateSet('PortableFirst', 'PathFirst', 'PortableOnly', 'PathOnly')]
    [string]$PluginSearchMode,
    [string]$PluginPath,
    [nullable[int]]$LogLevel,
    [nullable[int]]$ReportLogLevel,
    [string]$ReportPath,
    [ValidateSet('Compact', 'Standard', 'Verbose')]
    [string]$ReportVerbosity,
    [ValidateSet('Auto', 'Bytes', 'KB', 'MB', 'GB')]
    [string]$SizeDisplayUnit,
    [ValidateSet('Replace', 'OptimizedSuffix', 'BackupSuffix', 'BackupMove', 'TempMove')]
    [string]$OutputMode,
    [string]$BackupPath,
    [string]$BackupSuffix,
    [string]$OptimizedSuffix,
    [string]$TempBackupPath,
    [ValidateSet('Error', 'SkipTool', 'SkipFile')]
    [string]$MissingToolsPolicy,
    [nullable[bool]]$SkipMissingTools,
    [nullable[bool]]$HistoryEnabled,
    [string]$HistoryPath,
    [switch]$ShowProgress,
    [switch]$WhatIf,
    [switch]$Recurse,
    [switch]$ContinueOnError,
    [switch]$AcknowledgeOutdatedPlugins,
    [switch]$ShowHistory,
    [switch]$ShowConfig,
    [switch]$Version,
    [int]$Last = 10,
    [int]$LastBatches,
    [ValidateSet('Summary', 'Detailed', 'Object')]
    [string]$HistoryFormat = 'Summary'
)

$ErrorActionPreference = 'Stop'

try {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    $module = Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force -PassThru

    if ($Version) {
        Write-Output $module.Version.ToString()
        exit 0
    }

    if ($InitializeConfig) {
        Initialize-FoConfig -Scope $InitializeConfig -Path $ConfigPath -Force:$Force
        exit 0
    }

    if ($ShowConfig) {
        $cfg = Get-FoConfig -ConfigPath $ConfigPath
        $cfg.GetEnumerator() | Sort-Object Name | ForEach-Object {
            [PSCustomObject]@{ Name = $_.Key; Value = $_.Value }
        } | Format-List | Out-Host
        exit 0
    }

    if ($ShowHistory) {
        $histParams = @{
            HistoryPath     = $HistoryPath
            Format          = $HistoryFormat
            SizeDisplayUnit = if ($SizeDisplayUnit) { $SizeDisplayUnit } else { 'Auto' }
        }
        if ($LastBatches -gt 0) {
            $histParams.LastBatches = $LastBatches
        }
        else {
            $histParams.Last = $Last
        }
        Get-FoHistory @histParams
        exit 0
    }

    if (-not $Path -or $Path.Count -eq 0) {
        [Console]::Error.WriteLine('Specify at least one file or folder path.')
        exit 1
    }

    $params = @{}
    foreach ($key in @('Path','ConfigPath','Level','PluginSearchMode','PluginPath','LogLevel','ReportLogLevel','ReportPath','ReportVerbosity','SizeDisplayUnit','OutputMode','BackupPath','BackupSuffix','OptimizedSuffix','TempBackupPath','MissingToolsPolicy','SkipMissingTools','HistoryEnabled','HistoryPath','ShowProgress','WhatIf','Recurse','ContinueOnError','AcknowledgeOutdatedPlugins')) {
        if ($PSBoundParameters.ContainsKey($key)) { $params[$key] = $PSBoundParameters[$key] }
    }

    $results = @(Optimize-FoFile @params)
    if ($results | Where-Object { $_.Status -eq 'Error' }) {
        exit 1
    }

    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
