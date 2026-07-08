function Get-FoMP4Pipeline {
    param([hashtable]$Context)

    $s = $Context.Settings
    $meta = if ($s.MP4CopyMetadata) { '' } else { '-map_metadata -1 ' }
    $steps = @()

    $steps += New-FoStep -Name 'ffmpeg (1/2)' -Executable 'ffmpeg.exe' -Arguments "-i %INPUTFILE% -vcodec copy -acodec copy -map 0 $meta%TMPOUTPUTFILE%" -Mode TempOutput
    $steps += New-FoStep -Name 'mp4v2 (2/2)' -Executable 'mp4file.exe' -Arguments '--optimize -q %TMPINPUTFILE%' -Mode TempInput

    return $steps
}
