param(
    [ValidateSet('FullPortable', 'Missing')]
    [string]$Mode = 'FullPortable',
    [string]$PluginPath,
    [string]$ArchiveUrl,
    [string]$ArchiveSha256,
    [switch]$UseLegacySourceForge,
    [string]$TempDirectory,
    [switch]$Force,
    [switch]$WhatIf,
    [bool]$ShowProgress = $true
)

$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

$params = @{
    Mode                  = $Mode
    DestinationPath       = $PluginPath
    ArchiveUrl            = $ArchiveUrl
    ArchiveSha256         = $ArchiveSha256
    UseLegacySourceForge  = $UseLegacySourceForge
    TempDirectory         = $TempDirectory
    Force                 = $Force
    ShowProgress          = $ShowProgress
}
if ($WhatIf) {
    $params['WhatIf'] = $true
}

$result = Install-FoPlugins @params
$result | Format-List Mode, DestinationPath, Downloaded, Extracted, Message
if ($result.FilesCopied) {
    Write-Host "Copied $($result.FilesCopied.Count) file(s)."
}
if ($result.FilesMissing) {
    Write-Warning "Not found in bundle: $($result.FilesMissing -join ', ')"
}
