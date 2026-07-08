function Get-FoTGAPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $strip = if ($s.TGACopyMetadata) { '' } else { '-strip ' }
    $steps = @()

    $steps += New-FoStep -Name 'ImageMagick (1/1)' -Executable 'magick.exe' -Arguments "convert -quiet -compress RLE $strip%INPUTFILE% %TMPOUTPUTFILE%" -Mode TempOutput

    return $steps
}
