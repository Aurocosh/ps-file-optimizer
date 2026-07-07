function Get-FoPNGPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $leanify = Get-FoLeanifyIterations -Level $level -Override $s.LeanifyIterations
    $wolf = Get-FoLeanifyIterations -Level $level -Override $s.PNGWolfIterations
    $oxi = Get-FoOxiPngLevel -Level $level
    $steps = @()

    if ($Context.IsAPNG) {
        $steps += New-FoStep -Name 'apngopt (1/16)' -Executable 'apngopt.exe' -Arguments '"%INPUTFILE%" "%TMPOUTPUTFILE%"' -Mode TempOutput
    }

    if ($s.PNGAllowLossy -and -not $Context.IsAPNG) {
        $pq = if ($s.PNGCopyMetadata) { '' } else { '--strip ' }
        $steps += New-FoStep -Name 'pngquant (2/16)' -Executable 'pngquant.exe' -Arguments "$pq--quality=85-95 --speed 1 --ext .png --force `"%TMPINPUTFILE%`"" -Mode TempInput -Gate { -not $args[0].IsAPNG }
    }

    if (-not $Context.IsPNG9Patch) {
        $po = if ($s.PNGCopyMetadata) { '-KeepPhysicalPixelDimensions ' } else { '' }
        $steps += New-FoStep -Name 'PngOptimizer (3/16)' -Executable 'PngOptimizer.exe' -Arguments "${po}-file:`"%TMPINPUTFILE%`"" -Mode TempInput
    }

    if (-not $Context.IsAPNG -and -not $Context.IsPNG9Patch -and $Context.Extension -ne '.ico') {
        $tp = Get-FoTruePngLevel -Level $level
        $tf = if ($s.PNGCopyMetadata) { '-md keep all ' } else { '-tz -md remove all -a1 -g1 ' }
        if ($s.PNGAllowLossy) { $tf += '-l ' }
        $steps += New-FoStep -Name 'TruePNG (4/16)' -Executable 'truepng.exe' -Arguments "-o$tp $tf/i0 /nc /tz /quiet /y /out `"%TMPOUTPUTFILE%`" `"%INPUTFILE%`"" -Mode TempOutput
        $pn = Get-FoPngOutLevel -Level $level
        $pk = if ($s.PNGCopyMetadata) { '/k1 ' } else { '/kacTL,fcTL,fdAT ' }
        $steps += New-FoStep -Name 'PNGOut (5/16)' -Executable 'pngout.exe' -Arguments "/q /y /r /d0 /mincodes0 $pk/s$pn `"%INPUTFILE%`" `"%TMPOUTPUTFILE%`"" -Mode TempOutput
    }

    $strip = if ($Context.IsAPNG) { '--strip safe ' } elseif (-not $s.PNGCopyMetadata) { '--strip all ' } else { '--strip safe ' }
    $lossy = if ($s.PNGAllowLossy) { '--scale16 ' } else { '' }
    $steps += New-FoStep -Name 'OxiPNG (6/16)' -Executable 'oxipng.exe' -Arguments "--zopfli --alpha --quiet -o$oxi $lossy$strip`"%TMPINPUTFILE%`"" -Mode TempInput

    if (-not $Context.IsAPNG -and -not $s.PNGCopyMetadata) {
        $steps += New-FoStep -Name 'Leanify (8/16)' -Executable 'leanify.exe' -Arguments "-q -p -i $leanify `"%TMPINPUTFILE%`"" -Mode TempInput
        $steps += New-FoStep -Name 'pngwolf (9/16)' -Executable 'pngwolf.exe' -Arguments "--out-deflate=zopfli,iter=$wolf --in=`"%INPUTFILE%`" --out=`"%TMPOUTPUTFILE%`"" -Mode TempOutput
    }

    if (-not $Context.IsAPNG -and -not $Context.IsPNG9Patch) {
        $steps += New-FoStep -Name 'pngrewrite (10/16)' -Executable 'pngrewrite.exe' -Arguments '"%INPUTFILE%" "%TMPOUTPUTFILE%"' -Mode TempOutput
        if (-not $s.PNGCopyMetadata) {
            $steps += New-FoStep -Name 'advpng (11/16)' -Executable 'advpng.exe' -Arguments "-z -q -4 -i $leanify `"%TMPINPUTFILE%`"" -Mode TempInput
        }
    }

    $ect = Get-FoECTPreset -Level $level
    $reuse = if ($Context.IsAPNG) { '--reuse ' } else { '' }
    $steps += New-FoStep -Name 'ECT (12/16)' -Executable 'ECT.exe' -Arguments "-quiet --mt-deflate --mt-file --allfilters -png $reuse$ect `"%TMPINPUTFILE%`"" -Mode TempInput
    $steps += New-FoStep -Name 'pingo (13/16)' -Executable 'pingo.exe' -Arguments '-s9 -png "%TMPINPUTFILE%"' -Mode TempInput

    if (-not $Context.IsAPNG -and -not $Context.IsPNG9Patch) {
        $steps += New-FoStep -Name 'DeflOpt (14/16)' -Executable 'deflopt.exe' -Arguments '/a /b /s "%TMPINPUTFILE%"' -Mode TempInput
    }

    $steps += New-FoStep -Name 'defluff (15/16)' -Handler 'DefluffPipe' -Mode TempOutput

    if (-not $Context.IsAPNG -and -not $Context.IsPNG9Patch) {
        $steps += New-FoStep -Name 'DeflOpt (16/16)' -Executable 'deflopt.exe' -Arguments '/a /b /s "%TMPINPUTFILE%"' -Mode TempInput
    }

    return $steps
}
