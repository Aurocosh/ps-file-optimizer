function Install-FoPlugins {
    <#
    .SYNOPSIS
    Downloads plugin binaries and/or DSSIM for PS-FileOptimizer.

    .DESCRIPTION
    - **Plugins** — downloads the pinned ps-file-optimizer-aux .7z bundle, verifies SHA256,
      extracts with 7-Zip, and copies pipeline executables into a portable plugin directory.
    - **Dssim** — downloads the pinned [dssim](https://github.com/kornelski/dssim) 3.4.0 zip
      from GitHub releases, extracts `win/dssim.exe` only, and installs to `{plugins}/dssim/dssim.exe`.
      Skipped on 32-bit PowerShell (64-bit compare tool only).

    .PARAMETER Component
    Plugins — plugin bundle only (default, backward compatible).
    Dssim — DSSIM compare tool only.
    Both — plugin bundle and DSSIM.

    .PARAMETER Mode
    FullPortable — copy all executables required by pipelines (Plugins component only).
    Missing — copy only missing plugin executables (Plugins component only).

    .PARAMETER DestinationPath
    Target plugin directory root (flat plugin files + `dssim/` subfolder). Defaults to {ModuleRoot}\plugins.

    .NOTES
    Environment overrides:
    - Plugins: FO_PLUGIN_BUNDLE_URL, FO_PLUGIN_BUNDLE_SHA256, FO_PLUGIN_BUNDLE_FILENAME, FO_PLUGIN_BUNDLE_FORMAT
    - DSSIM: FO_DSSIM_BUNDLE_URL, FO_DSSIM_BUNDLE_SHA256, FO_DSSIM_BUNDLE_FILENAME

    .EXAMPLE
    Install-FoPlugins -Mode FullPortable

    .EXAMPLE
    Install-FoPlugins -Component Both -Mode FullPortable

    .EXAMPLE
    Install-FoPlugins -Component Dssim
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('FullPortable', 'Missing')]
        [string]$Mode = 'FullPortable',
        [ValidateSet('Plugins', 'Dssim', 'Both')]
        [string]$Component = 'Plugins',
        [Alias('PluginPath')]
        [string]$DestinationPath,
        [string]$ArchiveUrl,
        [string]$ArchiveSha256,
        [string]$DssimArchiveUrl,
        [string]$DssimArchiveSha256,
        [string]$TempDirectory,
        [switch]$Force,
        [bool]$ShowProgress = $true
    )

    $pluginResult = $null
    $dssimResult = $null

    if ($Component -in 'Plugins', 'Both') {
        $pluginResult = Install-FoPluginBundleCore -Mode $Mode -DestinationPath $DestinationPath `
            -ArchiveUrl $ArchiveUrl -ArchiveSha256 $ArchiveSha256 -TempDirectory $TempDirectory `
            -Force:$Force -ShowProgress:$ShowProgress
    }

    if ($Component -in 'Dssim', 'Both') {
        $dssimResult = Install-FoDssimBundleCore -DestinationPath $DestinationPath `
            -ArchiveUrl $DssimArchiveUrl -ArchiveSha256 $DssimArchiveSha256 -TempDirectory $TempDirectory `
            -Force:$Force -ShowProgress:$ShowProgress
    }

    if ($Component -eq 'Plugins') {
        return $pluginResult
    }
    if ($Component -eq 'Dssim') {
        return $dssimResult
    }

    return [PSCustomObject]@{
        Component = 'Both'
        Plugins   = $pluginResult
        Dssim     = $dssimResult
        Message   = @(
            if ($pluginResult) { $pluginResult.Message }
            if ($dssimResult) { $dssimResult.Message }
        ) -join ' '
    }
}
