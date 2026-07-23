function Get-FoJPEG2000Pipeline {
    param([hashtable]$Context)
    $null = $Context  # Reserved pipeline-host signature

    $steps = @()
    $steps += New-FoStep -Name 'ImageMagick (1/1)' -Executable 'magick.exe' -Arguments 'convert %INPUTFILE% -quiet -quality 0 %TMPOUTPUTFILE%' -Mode TempOutput
    return $steps
}
