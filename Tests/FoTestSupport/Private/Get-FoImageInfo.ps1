function Get-FoImageInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$MagickPath,
        [string]$PluginPath
    )

    $magick = Get-FoCompareMagickPath -MagickPath $MagickPath -PluginPath $PluginPath
    $workDir = Split-Path -Parent $magick

    $result = Invoke-FoMagickCli -MagickExe $magick -ArgumentList @(
        'identify'
        '-format'
        '%w %h %[channels] %m'
        $Path
    ) -WorkingDirectory $workDir

    if ($result.ExitCode -ne 0) {
        if (Test-FoCompareBmpPath -Path $Path) {
            $imagew = Get-FoCompareImagewPath -PluginPath $PluginPath
            $tempDir = [System.IO.Path]::GetTempPath()
            $tempPng = Join-Path $tempDir ("FoImageInfo_{0}.png" -f (Get-Random))
            try {
                ConvertTo-FoCompareNormalizedImageViaImagew -InputPath $Path -OutputPath $tempPng `
                    -ImagewExe $imagew -WorkingDirectory (Split-Path -Parent $imagew)
                $result = Invoke-FoMagickCli -MagickExe $magick -ArgumentList @(
                    'identify'
                    '-format'
                    '%w %h %[channels] %m'
                    $tempPng
                ) -WorkingDirectory $workDir
            }
            finally {
                if (Test-Path -LiteralPath $tempPng) {
                    Remove-Item -LiteralPath $tempPng -Force -ErrorAction SilentlyContinue
                }
            }
        }

        if ($result.ExitCode -ne 0) {
            throw "magick identify failed for '$Path': $($result.StdErr)"
        }
    }

    $parts = ($result.StdOut -split '\s+', 4)
    if ($parts.Count -lt 4) {
        throw "Unexpected magick identify output for '$Path': $($result.StdOut)"
    }

    return [PSCustomObject]@{
        Path     = $Path
        Width    = [int]$parts[0]
        Height   = [int]$parts[1]
        Channels = $parts[2]
        Format   = $parts[3]
    }
}
