function Get-FoOGGPipeline {
    param([hashtable]$Context)
    $null = $Context  # Reserved pipeline-host signature

    $steps = @()

    $steps += New-FoStep -Name 'OptiVorbis (1/2)' -Executable 'optivorbis.exe' -Arguments '--vendor_string_action empty --comment_fields_action delete %INPUTFILE% %TMPOUTPUTFILE%' -Mode TempOutput
    $steps += New-FoStep -Name 'rehuff_theora (2/2)' -Executable 'rehuff_theora.exe' -Arguments '%INPUTFILE% %TMPOUTPUTFILE%' -Mode TempOutput

    return $steps
}
