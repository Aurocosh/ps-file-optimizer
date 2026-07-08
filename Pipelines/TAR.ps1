function Get-FoTARPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $leanify = Get-FoLeanifyIterations -Level $level -Override $s.LeanifyIterations
    $keep = if ($s.GZCopyMetadata) { '--keep-exif ' } else { '' }
    $steps = @()

    $steps += New-FoStep -Name 'Leanify (1/1)' -Executable 'leanify.exe' -Arguments "-q -p -i $leanify $keep%TMPINPUTFILE%" -Mode TempInput

    return $steps
}
