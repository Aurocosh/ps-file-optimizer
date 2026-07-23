function Get-FoOBJPipeline {
    param([hashtable]$Context)
    $null = $Context  # Reserved pipeline-host signature

    $steps = @()
    $steps += New-FoStep -Name 'strip (1/1)' -Executable 'strip.exe' -Arguments '--strip-all -o %TMPOUTPUTFILE% %INPUTFILE%' -Mode TempOutput
    return $steps
}
