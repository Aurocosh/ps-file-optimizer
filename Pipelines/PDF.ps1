function Get-FoPDFPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $steps = @()

    $steps += New-FoStep -Name 'mutool (1/4)' -Executable 'mutool.exe' -Arguments 'clean -g -z "%INPUTFILE%" "%TMPOUTPUTFILE%"' -Mode TempOutput

    $arch = Resolve-FoPluginArchitectureFromPath -PluginPath $s.PluginPath
    $gs = Get-FoGhostscriptExecutableName -Architecture $arch
    $steps += New-FoStep -Name 'Ghostscript (2/4)' -Executable $gs -Arguments '-sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dNOPAUSE -dBATCH -dSAFER -sOutputFile="%TMPOUTPUTFILE%" "%INPUTFILE%"' -Mode TempOutput -Gate { $args[0].Extension -ne '.ai' }

    $steps += New-FoStep -Name 'cpdf (3/4)' -Executable 'cpdf.exe' -Arguments '-squeeze "%INPUTFILE%" -o "%TMPOUTPUTFILE%"' -Mode TempOutput
    $steps += New-FoStep -Name 'qpdf (4/4)' -Executable 'qpdf.exe' -Arguments '--stream-data=compress --object-streams=generate "%INPUTFILE%" "%TMPOUTPUTFILE%"' -Mode TempOutput

    return $steps
}
