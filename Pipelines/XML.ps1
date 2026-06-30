function Get-FoXMLPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $leanify = Get-FoLeanifyIterations -Level $level -Override $s.LeanifyIterations
    $gate = { $args[0].Settings.XMLEnableLeanify }
    $steps = @()

    $steps += New-FoStep -Name 'Leanify (1/2)' -Executable 'leanify.exe' -Arguments "-q -p -i $leanify `"%TMPINPUTFILE%`"" -Mode TempInput -Gate $gate
    $steps += New-FoStep -Name 'Minify (2/2)' -Executable 'minify.exe' -Arguments '"%INPUTFILE%" --output "%TMPOUTPUTFILE%"' -Mode TempOutput -Gate $gate

    return $steps
}
