function Get-FoMNGPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $leanify = Get-FoLeanifyIterations -Level $level -Override $s.LeanifyIterations
    $steps = @()

    $steps += New-FoStep -Name 'advmng (1/1)' -Executable 'advmng.exe' -Arguments "-z -r -q -4 -i $leanify %TMPINPUTFILE%" -Mode TempInput

    return $steps
}
