function Get-FoZIPPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $leanify = Get-FoLeanifyIterations -Level $level -Override $s.LeanifyIterations
    $ect = Get-FoECTPreset -Level $level
    $steps = @()

    $zipFlags = '--zip-deflate '
    if ($s.ZIPRecurse) { $zipFlags += '-d 1 ' }
    $steps += New-FoStep -Name 'Leanify (1/6)' -Executable 'leanify.exe' -Arguments "-q -p -i $leanify $zipFlags%TMPINPUTFILE%" -Mode TempInput

    $ectZip = "-quiet --mt-deflate --mt-file -zip $ect "
    if (-not $s.ZIPRecurse) { $ectZip += '--disable-png --disable-jpg ' }
    $steps += New-FoStep -Name 'ECT (2/6)' -Executable 'ECT.exe' -Arguments "$ectZip%TMPINPUTFILE%" -Mode TempInput

    $steps += New-FoStep -Name 'advzip (3/6)' -Executable 'advzip.exe' -Arguments '-z -q -4 "%TMPINPUTFILE%"' -Mode TempInput -Gate { -not $args[0].IsZipSFX }
    $steps += New-FoStep -Name 'DeflOpt (4/6)' -Executable 'deflopt.exe' -Arguments '/a /b /s "%TMPINPUTFILE%"' -Mode TempInput
    $steps += New-FoStep -Name 'defluff (5/6)' -Handler 'DefluffPipe' -Mode TempOutput
    $steps += New-FoStep -Name 'DeflOpt (6/6)' -Executable 'deflopt.exe' -Arguments '/a /b /s "%TMPINPUTFILE%"' -Mode TempInput

    return $steps
}
