function Get-FoDLLPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $upx = Get-FoUPXFlags -Level $level
    if ($level -ge 9) { $upx += ' --crp-ms=999999' }
    $steps = @()

    $steps += New-FoStep -Name 'PETrim (1/3)' -Executable 'petrim.exe' -Arguments '%TMPINPUTFILE%' -Mode TempInput -Gate { -not $args[0].Settings.EXEDisablePETrim }
    $steps += New-FoStep -Name 'strip (2/3)' -Executable 'strip.exe' -Arguments '--strip-all -o %TMPOUTPUTFILE% %INPUTFILE%' -Mode TempOutput
    $steps += New-FoStep -Name 'UPX (3/3)' -Executable 'upx.exe' -Arguments "--no-backup --force $upx %TMPINPUTFILE%" -Mode TempInput -Gate { $args[0].Settings.EXEEnableUPX }

    return $steps
}
