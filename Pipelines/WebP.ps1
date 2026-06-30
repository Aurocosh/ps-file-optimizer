function Get-FoWebPPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $level = $s.Level
    $pingoLevel = [math]::Min($level * 4 / 9, 4)
    $pingo = "-s$pingoLevel "
    if ($s.WEBPAllowLossy) { $pingo += '-quality=95 -webp ' } else { $pingo += '-lossless ' }
    if ($s.WEBPAllowLossy) {
        $cwebpLevel = [math]::Min($level * 6 / 9, 6)
        $cwebp = "-mt -quiet -m $cwebpLevel "
    }
    else {
        $cwebpLevel = [math]::Min($level, 9)
        $cwebp = "-mt -quiet -z $cwebpLevel -lossless "
    }
    $steps = @()

    $steps += New-FoStep -Name 'pingo (1/2)' -Executable 'pingo.exe' -Arguments "$pingo`"%TMPINPUTFILE%`"" -Mode TempInput
    $steps += New-FoStep -Name 'cwebp (2/2)' -Executable 'cwebp.exe' -Arguments "$cwebp`"%INPUTFILE%`" -o `"%TMPOUTPUTFILE%`"" -Mode TempOutput

    return $steps
}
