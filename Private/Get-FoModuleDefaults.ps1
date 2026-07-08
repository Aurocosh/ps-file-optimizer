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
        MiscCopyMetadata  = $false
        PDFSkipLayered    = $false
        PDFProfile        = 'none'
        TIFFCopyMetadata  = $false
        WAVCopyMetadata   = $false
        WAVStripSilence   = $false
        ZIPRecurse        = $false
        LeanifyIterations = -1
        PNGWolfIterations = -1
        PluginTimeoutSeconds = 1800
    }
}

function Get-FoGlobalConfigPath {
    if ($env:FO_CONFIG_PATH) { return $env:FO_CONFIG_PATH }
    return Join-Path (Join-Path (Join-Path $HOME '.config') 'FileOptimizer') 'config.json'
}

function Get-FoDefaultHistoryPath {
    if ($env:FO_HISTORY_PATH) { return $env:FO_HISTORY_PATH }
    return Join-Path (Join-Path (Join-Path $HOME '.config') 'FileOptimizer') 'history.json'
}

function Get-FoDefaultPluginPath {
    if (-not $script:FoModuleRoot) { return $null }

    if ($env:FO_PLUGIN_PATH) {
        $candidate = $env:FO_PLUGIN_PATH.Trim()
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return ([System.IO.Path]::GetFullPath($candidate))
        }
    }

    $prefer64 = [Environment]::Is64BitProcess
    $candidates = if ($prefer64) {
        @('Plugins64', 'Plugins32')
    }
    else {
        @('Plugins32', 'Plugins64')
    }

    foreach ($name in $candidates) {
        $candidate = Join-Path $script:FoModuleRoot $name
        if (Test-Path -LiteralPath $candidate) {
            return ([System.IO.Path]::GetFullPath($candidate))
        }
    }

    return $null
}
