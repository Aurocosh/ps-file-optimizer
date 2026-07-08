function Get-FoMP3Pipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $meta = if ($s.MP3CopyMetadata) { '' } else { '-t -s ' }
    $steps = @()

    $steps += New-FoStep -Name 'MP3packer (1/1)' -Executable 'mp3packer.exe' -Arguments "${meta}-z -a `"`" -A -f %INPUTFILE% %TMPOUTPUTFILE%" -Mode TempOutput

    return $steps
}
