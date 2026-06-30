function Get-FoMKVPipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $meta = if ($s.MP4CopyMetadata) { '' } else { '-map_metadata -1 ' }
    $steps = @()

    $steps += New-FoStep -Name 'ffmpeg (1/2)' -Executable 'ffmpeg.exe' -Arguments "-i `"%INPUTFILE%`" -vcodec copy -acodec copy -map 0 $meta`"%TMPOUTPUTFILE%`"" -Mode TempOutput
    $steps += New-FoStep -Name 'mkclean (2/2)' -Executable 'mkclean.exe' -Arguments '--optimize --unsafe --quiet "%INPUTFILE%" "%TMPOUTPUTFILE%"' -Mode TempOutput

    return $steps
}
