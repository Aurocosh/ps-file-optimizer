function Get-FoEXEPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $leanify = Get-FoLeanifyIterations -Level $level -Override $s.LeanifyIterations
    $upx = Get-FoUPXFlags -Level $level
    if ($level -ge 9) { $upx += ' --crp-ms=999999' }
    $gate = { -not $args[0].IsEXESFX }
    $steps = @()

    $steps += New-FoStep -Name 'Leanify (1/4)' -Executable 'leanify.exe' -Arguments "-q -p -i $leanify %TMPINPUTFILE%" -Mode TempInput -Gate $gate
    $steps += New-FoStep -Name 'PETrim (2/4)' -Executable 'petrim.exe' -Arguments '/StripFixups:Y "%TMPINPUTFILE%"' -Mode TempInput -Gate { -not $args[0].IsEXESFX -and -not $args[0].Settings.EXEDisablePETrim }
    $steps += New-FoStep -Name 'strip (3/4)' -Executable 'strip.exe' -Arguments '--strip-all -o "%TMPOUTPUTFILE%" "%INPUTFILE%"' -Mode TempOutput -Gate $gate
    $steps += New-FoStep -Name 'UPX (4/4)' -Executable 'upx.exe' -Arguments "--no-backup --force $upx %TMPINPUTFILE%" -Mode TempInput -Gate { -not $args[0].IsEXESFX -and $args[0].Settings.EXEEnableUPX }

    return $steps
}
