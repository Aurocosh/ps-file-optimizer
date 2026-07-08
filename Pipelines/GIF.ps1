function Get-FoGIFPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $strip = if ($s.GIFCopyMetadata) { '' } else { '-strip ' }
    $lossy = if ($s.GIFAllowLossy) { '--lossy=85 ' } else { '' }
    $steps = @()

    $steps += New-FoStep -Name 'ImageMagick (1/2)' -Executable 'magick.exe' -Arguments "convert %INPUTFILE% -quiet -layers optimize -compress LZW $strip%TMPOUTPUTFILE%" -Mode TempOutput
    $steps += New-FoStep -Name 'gifsicle (2/2)' -Executable 'gifsicle.exe' -Arguments "-w -j --no-conserve-memory -O3 ${lossy}-o %TMPOUTPUTFILE% %INPUTFILE%" -Mode TempOutput

    return $steps
}
