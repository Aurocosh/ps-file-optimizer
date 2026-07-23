function Get-FoConfig {
    <#
    .SYNOPSIS
    Returns merged FileOptimizer settings.

    .DESCRIPTION
    Merges module defaults, global config (%USERPROFILE%\.config\FileOptimizer\config.json),
    optional -ConfigPath, and any bound parameters passed to this cmdlet.

    .PARAMETER ConfigPath
    Optional local JSON config file merged after global config.

    .EXAMPLE
    Get-FoConfig

    .EXAMPLE
    $s = Get-FoConfig -ConfigPath .\my-settings.json
    $s.Level
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$ConfigPath
    )

    Merge-FoSettings -BoundParameters @{ ConfigPath = $ConfigPath }
}
