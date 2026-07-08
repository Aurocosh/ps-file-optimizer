function Get-FoPCXPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $strip = if ($s.PCXCopyMetadata) { '' } else { '-strip ' }
    $steps = @()

    $steps += New-FoStep -Name 'ImageMagick (1/1)' -Executable 'magick.exe' -Arguments "convert %INPUTFILE% -quiet -compress RLE $strip%TMPOUTPUTFILE%" -Mode TempOutput

    return $steps
}
