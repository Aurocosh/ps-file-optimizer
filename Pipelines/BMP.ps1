function Get-FoBMPPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $strip = if ($s.BMPCopyMetadata) { '' } else { '-strip ' }
    $steps = @()

    $steps += New-FoStep -Name 'ImageMagick (1/2)' -Executable 'magick.exe' -Arguments "convert %INPUTFILE% -quiet -compress RLE $strip%TMPOUTPUTFILE%" -Mode TempOutput
    $steps += New-FoStep -Name 'ImageWorsener (2/2)' -Executable 'imagew.exe' -Arguments '-opt bmp:version=auto -noresize -zipcmprlevel 9 -outfmt bmp -compress rle %INPUTFILE% %TMPOUTPUTFILE%' -Mode TempOutput

    return $steps
}
