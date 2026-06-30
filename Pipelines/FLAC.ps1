function Get-FoFLACPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $noMeta = { -not $args[0].Settings.WAVCopyMetadata }
    $flacFlags = if ($level -lt 3) { '-1 ' }
        elseif ($level -lt 5) { '-8 --best ' }
        elseif ($level -lt 7) { '-8 --best -e ' }
        else { '-8 --best -ep ' }
    if ($s.MiscCopyMetadata) { $flacFlags = "--keep-foreign-metadata $flacFlags" }
    $steps = @()

    $steps += New-FoStep -Name 'shntool (1/4)' -Executable 'shntool.exe' -Arguments 'strip -q -O always "%INPUTFILE%"' -Mode TempOutput -Gate $noMeta
    $steps += New-FoStep -Name 'shntool (2/4)' -Executable 'shntool.exe' -Arguments 'trim -q -O always "%INPUTFILE%"' -Mode TempOutput -Gate { -not $args[0].Settings.WAVCopyMetadata -and $args[0].Settings.WAVStripSilence }
    $steps += New-FoStep -Name 'FLAC (3/4)' -Executable 'flac.exe' -Arguments "--force -s $flacFlags`"%TMPINPUTFILE%`"" -Mode TempInput
    $steps += New-FoStep -Name 'FLACOut (4/4)' -Executable 'flacout.exe' -Arguments '/q /y "%INPUTFILE%" "%TMPOUTPUTFILE%"' -Mode TempOutput -Gate { $args[0].Settings.Level -ge 9 }

    return $steps
}
