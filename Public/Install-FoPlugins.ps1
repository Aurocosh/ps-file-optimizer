function Install-FoPlugins {
    <#
    .SYNOPSIS
    Downloads the plugin bundle and installs plugin binaries for PS-FileOptimizer.

    .DESCRIPTION
    Downloads a plain .7z archive from the pinned ps-file-optimizer-aux GitHub Release (default),
    verifies SHA256, extracts with 7-Zip, copies required plugin files into a portable plugin
    directory, then deletes temporary download and extracted files.

    Use -UseLegacySourceForge to download the FileOptimizer SFX from SourceForge instead.

    .PARAMETER Mode
    FullPortable — copy all executables and support files required by ps-file-optimizer pipelines.
    Missing — copy only executables not already present in DestinationPath (plus their support files).

    .PARAMETER DestinationPath
    Target plugin directory (flat folder of .exe / .dll files). Defaults to {ModuleRoot}\plugins.

    .PARAMETER ArchiveUrl
    Override the default bundle download URL. SHA256 verification applies only when -ArchiveSha256
    is also supplied (or FO_PLUGIN_BUNDLE_SHA256 is set).

    .PARAMETER ArchiveSha256
    Expected SHA256 of the bundle at -ArchiveUrl.

    .PARAMETER UseLegacySourceForge
    Download FileOptimizerFull.7z.exe from SourceForge instead of the aux release .7z.

    .PARAMETER TempDirectory
    Optional parent for temporary download/extract folders. A unique subfolder is always removed afterward.

    .PARAMETER Force
    Overwrite existing files in DestinationPath.

    .PARAMETER ShowProgress
    Display download progress. Default: true.

    .NOTES
    Environment overrides: FO_PLUGIN_BUNDLE_URL, FO_PLUGIN_BUNDLE_SHA256, FO_PLUGIN_BUNDLE_FILENAME,
    FO_PLUGIN_BUNDLE_FORMAT.

    .EXAMPLE
    Install-FoPlugins -Mode FullPortable

    .EXAMPLE
    Install-FoPlugins -Mode Missing -DestinationPath (Join-Path $HOME 'FoPlugins')
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('FullPortable', 'Missing')]
        [string]$Mode = 'FullPortable',
        [Alias('PluginPath')]
        [string]$DestinationPath,
        [string]$ArchiveUrl,
        [string]$ArchiveSha256,
        [switch]$UseLegacySourceForge,
        [string]$TempDirectory,
        [switch]$Force,
        [bool]$ShowProgress = $true
    )

    Install-FoPluginBundleCore @PSBoundParameters
}
