function Get-FoLuaPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $leanify = Get-FoLeanifyIterations -Level $level -Override $s.LeanifyIterations
    $steps = @()

    $steps += New-FoStep -Name 'Leanify (1/1)' -Executable 'leanify.exe' -Arguments "-q -p -i $leanify %TMPINPUTFILE%" -Mode TempInput -Gate { $args[0].Settings.LUAEnableLeanify }

    return $steps
}
