$script:FoPluginResolveCache = @{}

function Resolve-FoPluginExecutable {
    <#
    .SYNOPSIS
    Locates a plugin executable by name.

    .DESCRIPTION
    Searches the portable plugin directory and/or PATH according to -SearchMode.
    Results are cached for the module session.

    .PARAMETER Name
    Executable file name (for example magick.exe).

    .PARAMETER SearchMode
    PortableFirst — plugin folder then PATH (default).
    PathFirst — PATH then plugin folder.
    PortableOnly — plugin folder only.
    PathOnly — PATH only.

    .PARAMETER PluginPath
    Portable plugin directory. Defaults to module Plugins64/Plugins32 or FO_PLUGIN_PATH.

    .EXAMPLE
    Resolve-FoPluginExecutable -Name 'magick.exe' -SearchMode PortableFirst

    .EXAMPLE
    Resolve-FoPluginExecutable -Name 'oxipng.exe' -SearchMode PortableOnly -PluginPath .\Plugins64
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [ValidateSet('PortableFirst', 'PathFirst', 'PortableOnly', 'PathOnly')]
        [string]$SearchMode = 'PortableFirst',
        [string]$PluginPath
    )

    $cacheKey = "$SearchMode|$PluginPath|$Name"
    if ($script:FoPluginResolveCache.ContainsKey($cacheKey)) {
        return $script:FoPluginResolveCache[$cacheKey]
    }

    $nameLower = $Name.ToLowerInvariant()
    $portableDir = $PluginPath

    function Find-InDir([string]$dir) {
        if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { return $null }
        $item = Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name.ToLowerInvariant() -eq $nameLower } |
            Select-Object -First 1
        if ($item) { return $item.FullName }
        return $null
    }

    function Find-InPath {
        $cmd = Get-Command $Name -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) {
            return $cmd.Source
        }
        return $null
    }

    $path = $null
    $source = $null

    switch ($SearchMode) {
        'PortableFirst' {
            $path = Find-InDir $portableDir
            if ($path) { $source = 'Portable' }
            else {
                $path = Find-InPath
                if ($path) { $source = 'Path' }
            }
        }
        'PathFirst' {
            $path = Find-InPath
            if ($path) { $source = 'Path' }
            else {
                $path = Find-InDir $portableDir
                if ($path) { $source = 'Portable' }
            }
        }
        'PortableOnly' {
            $path = Find-InDir $portableDir
            if ($path) { $source = 'Portable' }
        }
        'PathOnly' {
            $path = Find-InPath
            if ($path) { $source = 'Path' }
        }
    }

    $result = [PSCustomObject]@{
        Name   = $Name
        Path   = $path
        Source = $source
        Found  = [bool]$path
    }
    $script:FoPluginResolveCache[$cacheKey] = $result
    return $result
}
