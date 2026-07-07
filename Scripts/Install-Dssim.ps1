param(
    [string]$PluginPath,
    [string]$ArchiveUrl,
    [string]$ArchiveSha256,
    [string]$TempDirectory,
    [switch]$Force,
    [switch]$AllowUnverifiedDownload,
    [switch]$WhatIf,
    [bool]$ShowProgress = $true
)

$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

$params = @{
    DestinationPath = $PluginPath
    ArchiveUrl               = $ArchiveUrl
    ArchiveSha256            = $ArchiveSha256
    TempDirectory            = $TempDirectory
    Force                    = $Force
    AllowUnverifiedDownload  = $AllowUnverifiedDownload
    ShowProgress             = $ShowProgress
}
if ($WhatIf) {
    $params['WhatIf'] = $true
}

$result = Install-FoDssim @params
$result | Format-List Version, DestinationPath, InstalledPath, Downloaded, Extracted, Skipped, Message
