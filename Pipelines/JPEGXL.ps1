function Get-FoJPEGXLPipeline {
    param([hashtable]$Context)

    $level = $Context.Settings.Level
    $steps = @()
    $steps += New-FoStep -Name 'ImageMagick (1/1)' -Executable 'magick.exe' -Arguments "convert %INPUTFILE% -quiet jxl:effort=$level %TMPOUTPUTFILE%" -Mode TempOutput
    return $steps
}
