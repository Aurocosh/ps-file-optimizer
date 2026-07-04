function Install-FoPlugins {
    <#
    .SYNOPSIS
    Downloads the FileOptimizer portable bundle and installs plugin binaries for PS-FileOptimizer.

    .DESCRIPTION
    Downloads FileOptimizerFull.7z.exe from a fixed URL, extracts it with 7-Zip (never runs the
    self-extracting stub), copies required plugin files into a portable plugin directory, then
    deletes the temporary download and extracted files.

    .PARAMETER Mode
    FullPortable — copy all executables and support files required by ps-file-optimizer pipelines.
    Missing — copy only executables not already present in DestinationPath (plus their support files).

    .PARAMETER DestinationPath
    Target plugin directory (flat folder of .exe / .dll files). Defaults to {ModuleRoot}\plugins.

    .PARAMETER ArchiveUrl
    Override the bundled FileOptimizer download URL.

    .PARAMETER TempDirectory
    Optional parent for temporary download/extract folders. A unique subfolder is always removed afterward.

    .PARAMETER Force
    Overwrite existing files in DestinationPath.

    .PARAMETER ShowProgress
    Display download progress for the FileOptimizer archive. Default: true.

    .EXAMPLE
    Install-FoPlugins -Mode FullPortable

    .EXAMPLE
    Install-FoPlugins -Mode Missing -DestinationPath D:\Tools\FoPlugins
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('FullPortable', 'Missing')]
        [string]$Mode = 'FullPortable',
        [Alias('PluginPath')]
        [string]$DestinationPath,
        [string]$ArchiveUrl,
        [string]$TempDirectory,
        [switch]$Force,
        [bool]$ShowProgress = $true
    )

    Install-FoPluginBundleCore @PSBoundParameters
}
