function Get-FoConfig {
    <#
    .SYNOPSIS
    Returns merged FileOptimizer settings.

    .DESCRIPTION
    Merges module defaults, global config (%USERPROFILE%\.config\FileOptimizer\config.psd1),
    optional -ConfigPath, and any bound parameters passed to this cmdlet.

    .PARAMETER ConfigPath
    Optional local PSD1 file merged after global config.

    .EXAMPLE
    Get-FoConfig

    .EXAMPLE
    $s = Get-FoConfig -ConfigPath .\my-settings.psd1
    $s.Level
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath
    )

    Merge-FoSettings -BoundParameters @{ ConfigPath = $ConfigPath }
}
