function Get-FoTIFFPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $cpus = [Environment]::ProcessorCount
    $jheadMeta = if ($s.TIFFCopyMetadata) { '-zt ' } else { '-purejpg -di -dx -dt -zt ' }
    $jpegStrip = if ($s.TIFFCopyMetadata) { '' } else { '--strip-all ' }
    $arith = if ($s.JPEGUseArithmeticEncoding) { '--with-arith ' } else { '' }
    $tranFlags = if ($s.JPEGUseArithmeticEncoding) { '-arithmetic ' } else { '' }
    $tranFlags += if ($s.TIFFCopyMetadata) { '-copy all ' } else { '-copy none ' }
    $steps = @()

    $steps += New-FoStep -Name 'jhead (1/6)' -Executable 'jhead.exe' -Arguments "-q -autorot $jheadMeta%TMPINPUTFILE%" -Mode TempInput -Gate { -not $args[0].IsJPEGCMYK }
    $steps += New-FoStep -Name 'ImageMagick (2/6)' -Executable 'magick.exe' -Arguments 'convert "%INPUTFILE%" -quiet -compress ZIP -strip "%TMPOUTPUTFILE%"' -Mode TempOutput -Gate { -not $args[0].Settings.TIFFCopyMetadata }
    $steps += New-FoStep -Name 'jpegoptim (3/6)' -Executable 'jpegoptim.exe' -Arguments "-o -q --all-progressive --nofix $jpegStrip$arith-w $cpus %TMPINPUTFILE%" -Mode TempInput
    $steps += New-FoStep -Name 'jpegtran (4/6)' -Executable 'jpegtran.exe' -Arguments "-progressive -optimize $tranFlags%INPUTFILE% %TMPOUTPUTFILE%" -Mode TempOutput
    $steps += New-FoStep -Name 'mozjpegtran (5/6)' -Executable 'mozjpegtran.exe' -Arguments "-outfile %TMPOUTPUTFILE% -progressive -optimize -perfect $tranFlags%INPUTFILE%" -Mode TempOutput
    $steps += New-FoStep -Name 'tinydng (6/6)' -Executable 'tinydng-cli.exe' -Arguments '--input "%INPUTFILE%" -l -o "%TMPOUTPUTFILE%"' -Mode TempOutput

    return $steps
}
