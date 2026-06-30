function Get-FoConfig {
    [CmdletBinding()]
    param(
        [string]$ConfigPath
    )

    Merge-FoSettings -BoundParameters @{ ConfigPath = $ConfigPath }
}
