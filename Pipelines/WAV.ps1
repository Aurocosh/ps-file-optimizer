function Get-FoWAVPipeline {
    param([hashtable]$Context)
    $null = $Context  # Reserved pipeline-host signature

    $noMeta = { -not $args[0].Settings.WAVCopyMetadata }
    $steps = @()

    $steps += New-FoStep -Name 'shntool (1/2)' -Executable 'shntool.exe' -Arguments 'strip -q -O always %INPUTFILE%' -Mode TempOutput -Gate $noMeta
    $steps += New-FoStep -Name 'shntool (2/2)' -Executable 'shntool.exe' -Arguments 'trim -q -O always %INPUTFILE%' -Mode TempOutput -Gate { -not $args[0].Settings.WAVCopyMetadata -and $args[0].Settings.WAVStripSilence }

    return $steps
}
