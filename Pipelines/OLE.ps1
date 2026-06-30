function Get-FoOLEPipeline {
    param([hashtable]$Context)

    $steps = @()

    $steps += New-FoStep -Name 'Document Press (1/2)' -Executable 'docprc.exe' -Arguments '-opt "%TMPINPUTFILE%"' -Mode TempInput
    $steps += New-FoStep -Name 'Best CFBF (2/2)' -Executable 'bestcfbf.exe' -Arguments '"%INPUTFILE%" "%TMPOUTPUTFILE%" -v4' -Mode TempOutput

    return $steps
}
