param(
    [ValidateSet('FullPortable', 'Missing')]
    [string]$Mode = 'FullPortable',
    [ValidateSet('Plugins', 'Dssim', 'Both')]
    [string]$Component = 'Plugins',
    [string]$PluginPath,
    [string]$ArchiveUrl,
    [string]$ArchiveSha256,
    [string]$DssimArchiveUrl,
    [string]$DssimArchiveSha256,
    [string]$TempDirectory,
    [switch]$Force,
    [switch]$WhatIf,
    [bool]$ShowProgress = $true
)

$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

$params = @{
    Mode               = $Mode
    Component          = $Component
    DestinationPath    = $PluginPath
    ArchiveUrl         = $ArchiveUrl
    ArchiveSha256      = $ArchiveSha256
    DssimArchiveUrl    = $DssimArchiveUrl
    DssimArchiveSha256 = $DssimArchiveSha256
    TempDirectory      = $TempDirectory
    Force              = $Force
    ShowProgress       = $ShowProgress
}
if ($WhatIf) {
    $params['WhatIf'] = $true
}

$result = Install-FoPlugins @params

if ($result.Component -eq 'Both') {
    if ($result.Plugins) {
        Write-Host '--- Plugins ---'
        $result.Plugins | Format-List Mode, DestinationPath, Downloaded, Extracted, Message
        if ($result.Plugins.FilesCopied) {
            Write-Host "Copied $($result.Plugins.FilesCopied.Count) plugin file(s)."
        }
    }
    if ($result.Dssim) {
        Write-Host '--- DSSIM ---'
        $result.Dssim | Format-List Version, InstalledPath, Downloaded, Extracted, Skipped, Message
    }
}
else {
    $result | Format-List Mode, Component, DestinationPath, InstalledPath, Downloaded, Extracted, Skipped, Message
    if ($result.FilesCopied) {
        Write-Host "Copied $($result.FilesCopied.Count) file(s)."
    }
    if ($result.FilesMissing) {
        Write-Warning "Not found in bundle: $($result.FilesMissing -join ', ')"
    }
}
