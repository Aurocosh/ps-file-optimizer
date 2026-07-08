function Get-FoHTMLPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $leanify = Get-FoLeanifyIterations -Level $level -Override $s.LeanifyIterations
    $gate = { $args[0].Settings.HTMLEnableTidy }
    $steps = @()

    $steps += New-FoStep -Name 'tidy (1/3)' -Executable 'tidy.exe' -Arguments '-config tidy.config -quiet -output "%TMPOUTPUTFILE%" "%INPUTFILE%"' -Mode TempOutput -Gate $gate
    $steps += New-FoStep -Name 'Minify (2/3)' -Executable 'minify.exe' -Arguments '"%INPUTFILE%" --output "%TMPOUTPUTFILE%"' -Mode TempOutput -Gate $gate
    $steps += New-FoStep -Name 'Leanify (3/3)' -Executable 'leanify.exe' -Arguments "-q -p -i $leanify %TMPINPUTFILE%" -Mode TempInput -Gate $gate

    return $steps
}
