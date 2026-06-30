function Get-FoModuleDefaults {
    [CmdletBinding()]
    param()

    @{
        Level             = 5
        OutputMode        = 'TempMove'
        TempBackupPath    = Join-Path $env:TEMP 'FileOptimizer\backups'
        PluginSearchMode  = 'PortableFirst'
        PluginPath        = $null
        LogLevel          = 1
        ReportLogLevel    = $null
        ReportPath        = $null
        SkipMissingTools  = $false
        BackupPath        = $null
        BackupSuffix      = '.bak'
        OptimizedSuffix   = '.optimized'
        HistoryEnabled    = $true
        HistoryPath       = $null
        DisablePluginMask = ''
        Debug             = $false
        TempDirectory     = $null
        IncludeMask       = ''
        ExcludeMask       = ''
        PNGCopyMetadata   = $false
        PNGAllowLossy     = $false
        JPEGCopyMetadata  = $false
        JPEGAllowLossy    = $false
        GIFCopyMetadata   = $false
        GIFAllowLossy     = $false
        GZCopyMetadata    = $false
        ZIPCopyMetadata   = $false
        EXEEnableUPX      = $false
        EXEDisablePETrim  = $false
        CSSEnableTidy     = $false
        HTMLEnableTidy    = $false
        JSEnableJSMin     = $false
        XMLEnableLeanify  = $false
        LUAEnableLeanify  = $false
        MiscDisable       = $false
        PDFSkipLayered    = $false
        LeanifyIterations = -1
        PNGWolfIterations = -1
    }
}

function Get-FoGlobalConfigPath {
    if ($env:FO_CONFIG_PATH) { return $env:FO_CONFIG_PATH }
    return Join-Path (Join-Path (Join-Path $HOME '.config') 'FileOptimizer') 'config.psd1'
}

function Get-FoDefaultHistoryPath {
    if ($env:FO_HISTORY_PATH) { return $env:FO_HISTORY_PATH }
    return Join-Path (Join-Path (Join-Path $HOME '.config') 'FileOptimizer') 'history.psd1'
}

function Get-FoDefaultPluginPath {
    if (-not $script:FoModuleRoot) { return $null }
    $arch = if ([Environment]::Is64BitProcess) { 'Plugins64' } else { 'Plugins32' }
    $candidates = @(
        (Join-Path $script:FoModuleRoot "..\FileOptimizerFull\$arch")
        (Join-Path $script:FoModuleRoot "..\..\FileOptimizerAnalisys\FileOptimizerFull\$arch")
    )
    foreach ($c in $candidates) {
        $resolved = [System.IO.Path]::GetFullPath($c)
        if (Test-Path -LiteralPath $resolved) { return $resolved }
    }
    return $null
}
