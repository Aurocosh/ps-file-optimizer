function Get-FoJPEGPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $leanify = Get-FoLeanifyIterations -Level $level -Override $s.LeanifyIterations
    $steps = @()

    $pingo = if ($s.JPEGAllowLossy) { '-quality=95 ' } else { "-s$level " }
    $steps += New-FoStep -Name 'pingo (1/11)' -Executable 'pingo.exe' -Arguments "$pingo%TMPINPUTFILE%" -Mode TempInput

    if ($s.JPEGAllowLossy -and -not $s.JPEGCopyMetadata) {
        $steps += New-FoStep -Name 'cjpegli (2/11)' -Executable 'cjpegli.exe' -Arguments "%INPUTFILE% %TMPOUTPUTFILE%" -Mode TempOutput
        $steps += New-FoStep -Name 'Guetzli (3/11)' -Executable 'guetzli.exe' -Arguments "%INPUTFILE% %TMPOUTPUTFILE%" -Mode TempOutput
        $steps += New-FoStep -Name 'jpeg-recompress (4/11)' -Executable 'jpeg-recompress.exe' -Arguments "%INPUTFILE% %TMPOUTPUTFILE%" -Mode TempOutput
    }

    if (-not $Context.IsJPEGCMYK) {
        $steps += New-FoStep -Name 'jhead (5/11)' -Executable 'jhead.exe' -Arguments '-purejpg -q "%TMPINPUTFILE%"' -Mode TempInput -Gate { -not $args[0].Settings.JPEGCopyMetadata }
    }

    $steps += New-FoStep -Name 'Leanify (6/11)' -Executable 'leanify.exe' -Arguments "-q -p -i $leanify %TMPINPUTFILE%" -Mode TempInput

    if ($s.JPEGAllowLossy) {
        $steps += New-FoStep -Name 'ImageMagick (7/11)' -Executable 'magick.exe' -Arguments 'convert "%INPUTFILE%" -quiet -interlace Plane -define jpeg:optimize-coding=true "%TMPOUTPUTFILE%"' -Mode TempOutput
    }

    $steps += New-FoStep -Name 'jpegoptim (8/11)' -Executable 'jpegoptim.exe' -Arguments '--all-progressive --strip-all --force "%TMPINPUTFILE%"' -Mode TempInput -Gate { -not $args[0].Settings.JPEGCopyMetadata }
    $steps += New-FoStep -Name 'jpegtran (9/11)' -Executable 'jpegtran.exe' -Arguments '-optimize -progressive -copy none -outfile "%TMPOUTPUTFILE%" "%INPUTFILE%"' -Mode TempOutput
    $steps += New-FoStep -Name 'mozjpegtran (10/11)' -Executable 'mozjpegtran.exe' -Arguments '-optimize -progressive -perfect -copy none -outfile "%TMPOUTPUTFILE%" "%INPUTFILE%"' -Mode TempOutput

    $ect = Get-FoECTPreset -Level $level
    $steps += New-FoStep -Name 'ECT (11/11)' -Executable 'ECT.exe' -Arguments "-quiet --mt-deflate --mt-file -progressive $ect %TMPINPUTFILE%" -Mode TempInput

    return $steps
}
