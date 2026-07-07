param(
    [ValidateSet('FullPortable', 'Missing', 'Remove')]
    [string]$Mode = 'FullPortable',
    [ValidateSet('Auto', '32', '64')]
    [string]$Architecture = 'Auto',
    [string]$PluginPath,
    [string]$ArchiveUrl,
    [string]$ArchiveSha256,
    [string]$TempDirectory,
    [switch]$Force,
    [switch]$AllowUnverifiedDownload,
    [switch]$WhatIf,
    [bool]$ShowProgress = $true
)

$ErrorActionPreference = 'Stop'

try {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

    $params = @{
        Mode                    = $Mode
        Architecture            = $Architecture
        DestinationPath         = $PluginPath
        ArchiveUrl              = $ArchiveUrl
        ArchiveSha256           = $ArchiveSha256
        TempDirectory           = $TempDirectory
        Force                   = $Force
        AllowUnverifiedDownload = $AllowUnverifiedDownload
        ShowProgress            = $ShowProgress
    }
    if ($WhatIf) {
        $params['WhatIf'] = $true
    }

    $result = Install-FoPlugins @params
    $result | Format-List Mode, Architecture, DestinationPath, Downloaded, Extracted, Message
    if ($result.RemovedPaths) {
        Write-Host "Removed: $($result.RemovedPaths -join ', ')"
    }
    if ($result.FilesCopied) {
        Write-Host "Copied $($result.FilesCopied.Count) file(s)."
    }
    if ($result.FilesMissing -and $result.FilesMissing.Count -gt 0) {
        Write-Warning "Not found in bundle: $($result.FilesMissing -join ', ')"
        exit 1
    }

    exit 0
}
catch {
    Write-Error $_
    exit 1
}
