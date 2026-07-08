function Get-FoMISCPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $strip = if ($s.MiscCopyMetadata) { '' } else { '-strip ' }
    $steps = @()

    $steps += New-FoStep -Name 'ImageMagick (1/1)' -Executable 'magick.exe' -Arguments "convert %INPUTFILE% -quiet $strip%TMPOUTPUTFILE%" -Mode TempOutput -Gate { -not $args[0].Settings.MiscDisable }

    return $steps
}
