function Get-FoSevenZipPipeline {
    param([hashtable]$Context)

    $m7zArgs = if ([Environment]::Is64BitProcess) {
        '-m1 -d1024 -mem2048 "%TMPINPUTFILE%"'
    }
    else {
        '-m1 -d128 -mem512 "%TMPINPUTFILE%"'
    }
    $steps = @()

    $steps += New-FoStep -Name 'm7zRepacker (1/1)' -Executable 'm7zrepacker.exe' -Arguments $m7zArgs -Mode TempInput -Gate { $args[0].Settings.Level -gt 7 }

    return $steps
}
