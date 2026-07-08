function Get-FoGZIPPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $leanify = Get-FoLeanifyIterations -Level $level -Override $s.LeanifyIterations
    $ect = Get-FoECTPreset -Level $level
    $noMeta = { -not $args[0].Settings.GZCopyMetadata }
    $deflFlags = if ($s.GZCopyMetadata) { '/c ' } else { '' }
    $ectStrip = if ($s.GZCopyMetadata) { '' } else { '-strip ' }
    $steps = @()

    $steps += New-FoStep -Name 'GzipRecompress (1/8)' -Handler 'GzipRecompress' -Mode TempOutput -Gate $noMeta
    $steps += New-FoStep -Name 'Leanify (2/8)' -Executable 'leanify.exe' -Arguments "-q -p -i $leanify %TMPINPUTFILE%" -Mode TempInput -Gate $noMeta
    $steps += New-FoStep -Name 'advdef (3/8)' -Executable 'advdef.exe' -Arguments "-z -q -4 -i $leanify %TMPINPUTFILE%" -Mode TempInput
    $steps += New-FoStep -Name 'zRecompress (4/8)' -Executable 'zRecompress.exe' -Arguments '-tgz "%TMPINPUTFILE%"' -Mode TempInput
    $steps += New-FoStep -Name 'ECT (5/8)' -Executable 'ECT.exe' -Arguments "-quiet --mt-deflate --mt-file --allfilters -gzip $ectStrip$ect %TMPINPUTFILE%" -Mode TempInput
    $steps += New-FoStep -Name 'DeflOpt (6/8)' -Executable 'deflopt.exe' -Arguments "/a /b /s $deflFlags%TMPINPUTFILE%" -Mode TempInput
    $steps += New-FoStep -Name 'defluff (7/8)' -Handler 'DefluffPipe' -Mode TempOutput
    $steps += New-FoStep -Name 'DeflOpt (8/8)' -Executable 'deflopt.exe' -Arguments "/a /b /s $deflFlags%TMPINPUTFILE%" -Mode TempInput

    return $steps
}
