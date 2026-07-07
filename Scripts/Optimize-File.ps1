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
    [ValidateSet('Replace', 'OptimizedSuffix', 'BackupSuffix', 'BackupMove', 'TempMove')]
    [string]$OutputMode,
    [string]$BackupPath,
    [string]$BackupSuffix,
    [string]$OptimizedSuffix,
    [string]$TempBackupPath,
    [nullable[bool]]$SkipMissingTools,
    [nullable[bool]]$HistoryEnabled,
    [string]$HistoryPath,
    [switch]$ShowProgress,
    [switch]$WhatIf,
    [switch]$Recurse,
    [switch]$ShowHistory,
    [int]$Last = 10,
    [ValidateSet('Summary', 'Detailed', 'Object')]
    [string]$HistoryFormat = 'Summary'
)

$ErrorActionPreference = 'Stop'

try {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

    if ($InitializeConfig) {
        Initialize-FoConfig -Scope $InitializeConfig -Path $ConfigPath -Force:$Force
        exit 0
    }

    if ($ShowHistory) {
        Get-FoHistory -Last $Last -HistoryPath $HistoryPath -Format $HistoryFormat
        exit 0
    }

    if (-not $Path -or $Path.Count -eq 0) {
        [Console]::Error.WriteLine('Specify at least one file or folder path.')
        exit 1
    }

    $params = @{}
    foreach ($key in @('Path','ConfigPath','Level','PluginSearchMode','PluginPath','LogLevel','ReportLogLevel','ReportPath','OutputMode','BackupPath','BackupSuffix','OptimizedSuffix','TempBackupPath','SkipMissingTools','HistoryEnabled','HistoryPath','ShowProgress','WhatIf','Recurse')) {
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
