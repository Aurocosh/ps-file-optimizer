function Get-FoCSSPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $template = if ($s.CSSTemplate) { $s.CSSTemplate } else { 'low' }
    $steps = @()

    $steps += New-FoStep -Name 'CSSTidy (1/2)' -Executable 'csstidy.exe' -Arguments "%INPUTFILE% --template=$template %TMPOUTPUTFILE%" -Mode TempOutput -Gate { $args[0].Settings.CSSEnableTidy }
    $steps += New-FoStep -Name 'Minify (2/2)' -Executable 'minify.exe' -Arguments '%INPUTFILE% --output %TMPOUTPUTFILE%' -Mode TempOutput -Gate { $args[0].Settings.CSSEnableTidy }

    return $steps
}
