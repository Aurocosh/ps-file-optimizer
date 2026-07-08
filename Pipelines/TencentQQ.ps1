function Get-FoTencentQQPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $leanify = Get-FoLeanifyIterations -Level $level -Override $s.LeanifyIterations
    $steps = @()

    $steps += New-FoStep -Name 'Leanify (1/1)' -Executable 'leanify.exe' -Arguments "-q -p -i $leanify %TMPINPUTFILE%" -Mode TempInput -Gate { -not $args[0].Settings.PNGCopyMetadata }

    return $steps
}
