function Install-FoPlugins {
    <#
    .SYNOPSIS
    Downloads the plugin bundle and installs plugin binaries for PS-FileOptimizer.

    .DESCRIPTION
    Downloads a plain .zip archive from the pinned ps-file-optimizer-aux GitHub Release (default),
    verifies SHA256, extracts with Expand-Archive, copies required plugin files into a portable plugin
    directory, then deletes temporary download and extracted files.

    Installs into {ModuleRoot}\Plugins64 or {ModuleRoot}\Plugins32 (never both). Legacy flat
    {ModuleRoot}\plugins is removed when switching architecture.

    .PARAMETER Mode
    FullPortable — copy all executables and support files required by ps-file-optimizer pipelines.
    Missing — copy only executables not already present in DestinationPath (plus their support files).
    Remove — delete Plugins64, Plugins32, and legacy plugins under the module root (no download).

    .PARAMETER Architecture
    Auto — match the current PowerShell process bitness (64-bit → Plugins64, 32-bit → Plugins32).
    32 or 64 — force a specific bundle and destination folder.

    .PARAMETER DestinationPath
    Target plugin directory. Defaults to {ModuleRoot}\Plugins64 or {ModuleRoot}\Plugins32 per -Architecture.

    .PARAMETER ArchiveUrl
    Override the default bundle download URL. Custom URLs require -ArchiveSha256 unless
    -AllowUnverifiedDownload is specified.

    .PARAMETER ArchiveSha256
    Expected SHA256 of the bundle at -ArchiveUrl.

    .PARAMETER AllowUnverifiedDownload
    Allow downloading a custom bundle URL without SHA256 verification. Not recommended.

    .PARAMETER TempDirectory
    Optional parent for temporary download/extract folders. A unique subfolder is always removed afterward.

    .PARAMETER Force
    Overwrite existing files in DestinationPath.

    .PARAMETER ShowProgress
    Display download progress. Default: true.

    .NOTES
    Environment overrides: FO_PLUGIN_BUNDLE_URL, FO_PLUGIN_BUNDLE_SHA256, FO_PLUGIN_BUNDLE_FILENAME,
    FO_PLUGIN_BUNDLE_FORMAT, FO_PLUGIN_BUNDLE_ARCH, FO_PLUGIN_BUNDLE_FOLDER, FO_PLUGIN_BUNDLE_CACHE_DIR.

    For the optional DSSIM compare tool (test-only), use `Install-FoDssim` or `Scripts/Install-Dssim.ps1`.

    .EXAMPLE
    Install-FoPlugins -Mode FullPortable

    .EXAMPLE
    Install-FoPlugins -Mode Remove

    .EXAMPLE
    Install-FoPlugins -Mode Missing -Architecture 64 -DestinationPath (Join-Path $HOME 'FoPlugins64')
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('FullPortable', 'Missing', 'Remove')]
        [string]$Mode = 'FullPortable',
        [ValidateSet('Auto', '32', '64')]
        [string]$Architecture = 'Auto',
        [Alias('PluginPath')]
        [string]$DestinationPath,
        [string]$ArchiveUrl,
        [string]$ArchiveSha256,
        [string]$TempDirectory,
        [switch]$Force,
        [switch]$AllowUnverifiedDownload,
        [bool]$ShowProgress = $true
    )

    Install-FoPluginBundleCore @PSBoundParameters
}
