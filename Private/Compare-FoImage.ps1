function Get-FoCompareMagickPath {
    [CmdletBinding()]
    param(
        [string]$MagickPath,
        [string]$PluginPath
    )

    if ($MagickPath) {
        if (-not (Test-Path -LiteralPath $MagickPath)) {
            throw "MagickPath not found: $MagickPath"
        }
        return ([System.IO.Path]::GetFullPath($MagickPath))
    }

    $searchPath = $PluginPath
    if (-not $searchPath) {
        if (Get-Command Get-FoTestPluginPath -ErrorAction SilentlyContinue) {
            $searchPath = Get-FoTestPluginPath
        }
        elseif (Get-Command Get-FoDefaultPluginPath -ErrorAction SilentlyContinue) {
            $searchPath = Get-FoDefaultPluginPath
        }
    }

    $resolved = Resolve-FoPluginExecutable -Name 'magick.exe' -SearchMode PortableFirst -PluginPath $searchPath
    if (-not $resolved.Found) {
        throw 'magick.exe not found. Set FO_TEST_PLUGIN_PATH or pass -MagickPath.'
    }

    return $resolved.Path
}

function Invoke-FoMagickCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MagickExe,
        [Parameter(Mandatory)]
        [string[]]$ArgumentList,
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds = 90
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $MagickExe
    $psi.Arguments = ($ArgumentList | ForEach-Object {
            if ($_ -match '\s') { "`"$_`"" } else { $_ }
        }) -join ' '
    $psi.WorkingDirectory = if ($WorkingDirectory) { $WorkingDirectory } else { Split-Path -Parent $MagickExe }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $null = $process.Start()

    # Read stdout/stderr asynchronously to avoid pipe-buffer deadlocks when both streams are used.
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    $timeoutMs = [Math]::Max(1, $TimeoutSeconds) * 1000
    $exited = $process.WaitForExit($timeoutMs)

    if (-not $exited) {
        try { $process.Kill() } catch { }
        $null = $process.WaitForExit(5000)
        $process.Dispose()
        return @{
            ExitCode = -1
            StdOut   = ''
            StdErr   = "magick.exe timed out after ${TimeoutSeconds}s"
            TimedOut = $true
        }
    }

    $result = @{
        ExitCode = $process.ExitCode
        StdOut   = $stdoutTask.GetAwaiter().GetResult().Trim()
        StdErr   = $stderrTask.GetAwaiter().GetResult().Trim()
        TimedOut = $false
    }
    $process.Dispose()
    return $result
}

function ConvertTo-FoCompareNormalizedImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [Parameter(Mandatory)]
        [string]$MagickExe,
        [string]$WorkingDirectory
    )

    $result = Invoke-FoMagickCli -MagickExe $MagickExe -WorkingDirectory $WorkingDirectory -ArgumentList @(
        $InputPath
        '-auto-orient'
        '-alpha', 'on'
        '-background', 'black'
        '-flatten'
        '-colorspace', 'sRGB'
        '-depth', '8'
        "png32:$OutputPath"
    )

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) {
        throw "Failed to normalize '$InputPath' for compare: $($result.StdErr)"
    }
}

function Get-FoCompareMetricValue {
    param(
        [string]$MetricOutput,
        [ValidateSet('AE', 'SSIM')]
        [string]$Metric = 'AE'
    )

    if ([string]::IsNullOrWhiteSpace($MetricOutput)) {
        return $null
    }

    $culture = [Globalization.CultureInfo]::InvariantCulture

    if ($Metric -eq 'SSIM' -and $MetricOutput -match '\(([0-9]+(?:[.,][0-9]+)?)\)\s*$') {
        $token = $Matches[1] -replace ',', '.'
        return [double]::Parse($token, $culture)
    }

    $token = ($MetricOutput -split '\s+')[0] -replace ',', '.'
    if ($token -match '^[\d.]+$') {
        return [double]::Parse($token, $culture)
    }

    return $null
}

function Compare-FoImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Before,
        [Parameter(Mandatory)]
        [string]$After,
        [ValidateSet('Pixel', 'SSIM')]
        [string]$Mode = 'Pixel',
        [double]$SSIMDissimilarityMaximum = 0,
        [string]$MagickPath,
        [string]$PluginPath,
        [string]$DiffOutputPath
    )

    if (-not (Test-Path -LiteralPath $Before)) {
        throw "Before image not found: $Before"
    }
    if (-not (Test-Path -LiteralPath $After)) {
        throw "After image not found: $After"
    }

    $magick = Get-FoCompareMagickPath -MagickPath $MagickPath -PluginPath $PluginPath
    $workDir = Split-Path -Parent $magick
    $tempDir = [System.IO.Path]::GetTempPath()
    $token = "FoCompare_$(Get-Random)"
    $beforeNorm = Join-Path $tempDir "${token}_before.png"
    $afterNorm = Join-Path $tempDir "${token}_after.png"

    try {
        ConvertTo-FoCompareNormalizedImage -InputPath $Before -OutputPath $beforeNorm -MagickExe $magick -WorkingDirectory $workDir
        ConvertTo-FoCompareNormalizedImage -InputPath $After -OutputPath $afterNorm -MagickExe $magick -WorkingDirectory $workDir

        $beforeInfo = Get-FoImageInfo -Path $Before -MagickPath $magick -PluginPath $PluginPath
        $metricName = if ($Mode -eq 'Pixel') { 'AE' } else { 'SSIM' }
        $compareArgs = @(
            'compare'
            '-define', 'compare:virtual-pixels=false'
            '-metric', $metricName
            $beforeNorm
            $afterNorm
            'null:'
        )

        $compareResult = Invoke-FoMagickCli -MagickExe $magick -WorkingDirectory $workDir -ArgumentList $compareArgs
        $metricRaw = $compareResult.StdErr
        if (-not $metricRaw) { $metricRaw = $compareResult.StdOut }

        $metricValue = Get-FoCompareMetricValue -MetricOutput $metricRaw -Metric $metricName
        $pass = $false
        $metricDisplay = $metricRaw

        if ($Mode -eq 'Pixel') {
            $pass = ($metricValue -eq 0)
            if ($null -eq $metricValue) {
                $pass = ($metricRaw -match '^0\s*\(')
            }
        }
        else {
            if ($null -eq $metricValue) {
                throw "Could not parse SSIM metric from magick compare: '$metricRaw'"
            }
            # ImageMagick compare -metric SSIM reports dissimilarity (0 = identical, higher = more different).
            $pass = ($metricValue -le $SSIMDissimilarityMaximum)
            $metricDisplay = [string]$metricValue
        }

        $diffPath = $null
        if ($DiffOutputPath -and -not $pass) {
            $diffDir = Split-Path -Parent $DiffOutputPath
            if ($diffDir -and -not (Test-Path -LiteralPath $diffDir)) {
                New-Item -ItemType Directory -Path $diffDir -Force | Out-Null
            }
            $null = Invoke-FoMagickCli -MagickExe $magick -WorkingDirectory $workDir -ArgumentList @(
                'compare'
                '-compose', 'src'
                $beforeNorm
                $afterNorm
                '-highlight-color', 'red'
                '-lowlight-color', 'white'
                $DiffOutputPath
            )
            if (Test-Path -LiteralPath $DiffOutputPath) {
                $diffPath = $DiffOutputPath
            }
        }

        return [PSCustomObject]@{
            Pass       = $pass
            Mode       = $Mode
            Metric     = $metricDisplay
            MetricValue = $metricValue
            DiffPath   = $diffPath
            Width      = $beforeInfo.Width
            Height     = $beforeInfo.Height
            BeforePath = $Before
            AfterPath  = $After
        }
    }
    finally {
        foreach ($tempFile in @($beforeNorm, $afterNorm)) {
            if (Test-Path -LiteralPath $tempFile) {
                Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
