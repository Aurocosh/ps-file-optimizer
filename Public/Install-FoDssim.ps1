function Install-FoDssim {
    <#
    .SYNOPSIS
    Downloads DSSIM for image test compare workflows (not used by optimization).

    .DESCRIPTION
    Downloads the pinned [dssim](https://github.com/kornelski/dssim) 3.4.0 zip from GitHub
    releases, verifies SHA256, extracts `win/dssim.exe` only, and installs to
    `{plugins}/dssim/dssim.exe`. Skipped on 32-bit PowerShell (64-bit compare tool only).

    DSSIM is used by `Compare-FoImage` for PNG lossless verification in the test suite. It is not
    part of optimization pipelines and is not required to optimize files.

    .PARAMETER DestinationPath
    Plugin directory root (same folder as pipeline executables). Defaults to Plugins64 or Plugins32 under the module root.

    .PARAMETER ArchiveUrl
    Override the default dssim zip download URL. Custom URLs require -ArchiveSha256 unless
    -AllowUnverifiedDownload is specified.

    .PARAMETER ArchiveSha256
    Expected SHA256 of the bundle at -ArchiveUrl.

    .PARAMETER AllowUnverifiedDownload
    Allow downloading a custom bundle URL without SHA256 verification. Not recommended.

    .PARAMETER TempDirectory
    Optional parent for temporary download/extract folders. A unique subfolder is always removed afterward.

    .PARAMETER Force
    Re-download and overwrite an existing `dssim/dssim.exe`.

    .PARAMETER ShowProgress
    Display download progress. Default: true.

    .NOTES
    Exported for convenience when running image tests locally; optimization does not depend on this cmdlet.
    Environment overrides: FO_DSSIM_BUNDLE_URL, FO_DSSIM_BUNDLE_SHA256, FO_DSSIM_BUNDLE_FILENAME.

    .EXAMPLE
    Install-FoDssim

    .EXAMPLE
    Install-FoDssim -DestinationPath (Join-Path $HOME 'FoPlugins') -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Alias('PluginPath')]
        [string]$DestinationPath,
        [string]$ArchiveUrl,
        [string]$ArchiveSha256,
        [string]$TempDirectory,
        [switch]$Force,
        [switch]$AllowUnverifiedDownload,
        [bool]$ShowProgress = $true
    )

    $target = if ($DestinationPath) { $DestinationPath } else { 'default plugin directory' }
    $action = 'Download and install DSSIM compare tool'

    if ($PSCmdlet.ShouldProcess($target, $action)) {
        return Install-FoDssimBundleCore @PSBoundParameters -Confirm:$false
    }

    if ($WhatIfPreference) {
        return Install-FoDssimBundleCore @PSBoundParameters
    }
}
