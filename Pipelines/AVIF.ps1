function Get-FoAVIFPipeline {
    param([hashtable]$Context)
    $null = $Context  # Reserved pipeline-host signature

    $steps = @()
    $steps += New-FoStep -Name 'ImageMagick (1/1)' -Executable 'magick.exe' -Arguments 'convert %INPUTFILE% -quiet -define heic:speed=1 %TMPOUTPUTFILE%' -Mode TempOutput
    return $steps
}
