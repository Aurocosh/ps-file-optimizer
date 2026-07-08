function Get-FoJSPipeline {
    param([hashtable]$Context)

    $gate = { $args[0].Settings.JSEnableJSMin }
    $steps = @()

    $steps += New-FoStep -Name 'jsmin (1/2)' -Handler 'JsMinPipe' -Mode TempOutput -Gate $gate
    $steps += New-FoStep -Name 'Minify (2/2)' -Executable 'minify.exe' -Arguments '%INPUTFILE% --output %TMPOUTPUTFILE%' -Mode TempOutput -Gate $gate

    return $steps
}
