function Get-FoPDFPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $layeredGate = {
        -not $args[0].IsPDFLayered -or
        -not $args[0].Settings.PDFSkipLayered -or
        ($args[0].Settings.PDFProfile -eq 'none')
    }
    $steps = @()

    $steps += New-FoStep -Name 'mutool (1/4)' -Executable 'mutool.exe' -Arguments 'clean -g -z "%INPUTFILE%" "%TMPOUTPUTFILE%"' -Mode TempOutput -Gate $layeredGate

    $arch = Resolve-FoPluginArchitectureFromPath -PluginPath $s.PluginPath
    $gs = Get-FoGhostscriptExecutableName -Architecture $arch
    $gsGate = {
        ($args[0].Extension -ne '.ai') -and (
            (-not $args[0].IsPDFLayered) -or
            (-not $args[0].Settings.PDFSkipLayered) -or
            ($args[0].Settings.PDFProfile -eq 'none')
        )
    }
    $steps += New-FoStep -Name 'Ghostscript (2/4)' -Executable $gs -Arguments '-sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dNOPAUSE -dBATCH -dSAFER -sOutputFile="%TMPOUTPUTFILE%" "%INPUTFILE%"' -Mode TempOutput -Gate $gsGate

    $steps += New-FoStep -Name 'cpdf (3/4)' -Executable 'cpdf.exe' -Arguments '-squeeze "%INPUTFILE%" -o "%TMPOUTPUTFILE%"' -Mode TempOutput -Gate $layeredGate
    $steps += New-FoStep -Name 'qpdf (4/4)' -Executable 'qpdf.exe' -Arguments '--stream-data=compress --object-streams=generate "%INPUTFILE%" "%TMPOUTPUTFILE%"' -Mode TempOutput -Gate $layeredGate

    return $steps
}
