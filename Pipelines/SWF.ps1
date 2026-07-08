function Get-FoSWFPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $leanify = Get-FoLeanifyIterations -Level $level -Override $s.LeanifyIterations
    $steps = @()

    $steps += New-FoStep -Name 'flasm (1/5)' -Executable 'flasm.exe' -Arguments '-x "%INPUTFILE%"' -Mode InPlace
    $steps += New-FoStep -Name 'flasm (2/5)' -Executable 'flasm.exe' -Arguments '-u "%INPUTFILE%"' -Mode InPlace
    $steps += New-FoStep -Name 'flasm (3/5)' -Executable 'flasm.exe' -Arguments '-z "%INPUTFILE%"' -Mode InPlace
    $steps += New-FoStep -Name 'zRecompress (4/5)' -Executable 'zRecompress.exe' -Arguments '-tswf-lzma "%TMPINPUTFILE%"' -Mode TempInput
    $steps += New-FoStep -Name 'Leanify (5/5)' -Executable 'leanify.exe' -Arguments "-q -p -i $leanify %TMPINPUTFILE%" -Mode TempInput

    return $steps
}
