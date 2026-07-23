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

function Get-FoCompareFfmpegPath {
    [CmdletBinding()]
    param(
        [string]$PluginPath
    )

    $searchPath = $PluginPath
    if (-not $searchPath) {
        if (Get-Command Get-FoTestPluginPath -ErrorAction SilentlyContinue) {
            $searchPath = Get-FoTestPluginPath
        }
        elseif (Get-Command Get-FoDefaultPluginPath -ErrorAction SilentlyContinue) {
            $searchPath = Get-FoDefaultPluginPath
        }
    }

    $resolved = Resolve-FoPluginExecutable -Name 'ffmpeg.exe' -SearchMode PortableFirst -PluginPath $searchPath
    if (-not $resolved.Found) {
        throw 'ffmpeg.exe not found. Set FO_TEST_PLUGIN_PATH or pass -PluginPath.'
    }

    return $resolved.Path
}

function Get-FoCompareImagewPath {
    [CmdletBinding()]
    param(
        [string]$PluginPath
    )

    $searchPath = $PluginPath
    if (-not $searchPath) {
        if (Get-Command Get-FoTestPluginPath -ErrorAction SilentlyContinue) {
            $searchPath = Get-FoTestPluginPath
        }
        elseif (Get-Command Get-FoDefaultPluginPath -ErrorAction SilentlyContinue) {
            $searchPath = Get-FoDefaultPluginPath
        }
    }

    $resolved = Resolve-FoPluginExecutable -Name 'imagew.exe' -SearchMode PortableFirst -PluginPath $searchPath
    if (-not $resolved.Found) {
        throw 'imagew.exe not found. Set FO_TEST_PLUGIN_PATH or pass -PluginPath.'
    }

    return $resolved.Path
}

function Test-FoCompareBmpPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $extension = [System.IO.Path]::GetExtension($Path)
    return ($extension -match '(?i)^\.(bmp|dib)$')
}

function Test-FoComparePngPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $extension = [System.IO.Path]::GetExtension($Path)
    return ($extension -match '(?i)^\.png$')
}

function Get-FoCompareDssimPathOptional {
    [CmdletBinding()]
    param(
        [string]$PluginPath
    )

    if (-not [Environment]::Is64BitProcess) {
        return $null
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
    if (-not $searchPath) {
        return $null
    }

    $candidate = Join-Path ([System.IO.Path]::GetFullPath($searchPath)) 'dssim\dssim.exe'
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }

    return $null
}

function Invoke-FoDssimCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DssimExe,
        [Parameter(Mandatory)]
        [string]$Before,
        [Parameter(Mandatory)]
        [string]$After,
        [string]$DiffOutputPath,
        [int]$TimeoutSeconds = 90
    )

    $argumentList = @($Before, $After)
    if ($DiffOutputPath) {
        $argumentList = @('-o', $DiffOutputPath) + $argumentList
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $DssimExe
    $psi.Arguments = ($argumentList | ForEach-Object {
            if ($_ -match '\s') { "`"$_`"" } else { $_ }
        }) -join ' '
    $psi.WorkingDirectory = Split-Path -Parent $DssimExe
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $null = $process.Start()

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    $timeoutMs = [Math]::Max(1, $TimeoutSeconds) * 1000
    $exited = $process.WaitForExit($timeoutMs)

    if (-not $exited) {
        try { $process.Kill() } catch { }
        $null = $process.WaitForExit(5000)
        $process.Dispose()
        throw "dssim.exe timed out after ${TimeoutSeconds}s"
    }

    $stdout = $stdoutTask.GetAwaiter().GetResult().Trim()
    $stderr = $stderrTask.GetAwaiter().GetResult().Trim()
    $exitCode = $process.ExitCode
    $process.Dispose()

    if ($exitCode -ne 0) {
        $detail = if ($stderr) { $stderr } elseif ($stdout) { $stdout } else { "exit code $exitCode" }
        throw "dssim compare failed: $detail"
    }

    $line = ($stdout -split "`n")[0].Trim()
    $score = $null
    if ($line -match '^([\d.]+(?:e[-+]?\d+)?)\s') {
        $token = $Matches[1] -replace ',', '.'
        $score = [double]::Parse($token, [Globalization.CultureInfo]::InvariantCulture)
    }
    elseif ($line -match '^([\d.]+(?:e[-+]?\d+)?)$') {
        $token = $Matches[1] -replace ',', '.'
        $score = [double]::Parse($token, [Globalization.CultureInfo]::InvariantCulture)
    }
    else {
        throw "Unexpected dssim output: '$stdout'"
    }

    return @{
        Score   = $score
        RawLine = $line
        StdErr  = $stderr
    }
}

function Compare-FoImageViaDssim {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Before,
        [Parameter(Mandatory)]
        [string]$After,
        [Parameter(Mandatory)]
        [string]$DssimExe,
        [double]$DissimilarityMaximum = 0,
        [string]$MagickPath,
        [string]$PluginPath,
        [string]$DiffOutputPath
    )

    $diffPath = $null
    if ($DiffOutputPath) {
        $diffDir = Split-Path -Parent $DiffOutputPath
        if ($diffDir -and -not (Test-Path -LiteralPath $diffDir)) {
            New-Item -ItemType Directory -Path $diffDir -Force | Out-Null
        }
    }

    $result = Invoke-FoDssimCli -DssimExe $DssimExe -Before $Before -After $After -DiffOutputPath $DiffOutputPath
    $pass = ($result.Score -le $DissimilarityMaximum)

    if ($DiffOutputPath -and -not $pass -and (Test-Path -LiteralPath $DiffOutputPath)) {
        $diffPath = $DiffOutputPath
    }

    $magick = Get-FoCompareMagickPath -MagickPath $MagickPath -PluginPath $PluginPath
    $beforeInfo = $null
    try {
        $beforeInfo = Get-FoImageInfo -Path $Before -MagickPath $magick -PluginPath $PluginPath
    }
    catch {
        throw "dssim compare succeeded but magick identify failed for '$Before': $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        Pass        = $pass
        Mode        = 'Pixel'
        Metric      = $result.RawLine
        MetricValue = $result.Score
        DiffPath    = $diffPath
        Width       = $beforeInfo.Width
        Height      = $beforeInfo.Height
        BeforePath  = $Before
        AfterPath   = $After
        CompareTool = 'Dssim'
    }
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

function Invoke-FoFfmpegCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FfmpegExe,
        [Parameter(Mandatory)]
        [string[]]$ArgumentList,
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds = 90
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FfmpegExe
    $psi.Arguments = ($ArgumentList | ForEach-Object {
            if ($_ -match '\s') { "`"$_`"" } else { $_ }
        }) -join ' '
    $psi.WorkingDirectory = if ($WorkingDirectory) { $WorkingDirectory } else { Split-Path -Parent $FfmpegExe }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $null = $process.Start()

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
            StdErr   = "ffmpeg.exe timed out after ${TimeoutSeconds}s"
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

function Invoke-FoImagewCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ImagewExe,
        [Parameter(Mandatory)]
        [string[]]$ArgumentList,
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds = 90
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ImagewExe
    $psi.Arguments = ($ArgumentList | ForEach-Object {
            if ($_ -match '\s') { "`"$_`"" } else { $_ }
        }) -join ' '
    $psi.WorkingDirectory = if ($WorkingDirectory) { $WorkingDirectory } else { Split-Path -Parent $ImagewExe }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $null = $process.Start()

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
            StdOut   = $stdoutTask.GetAwaiter().GetResult().Trim()
            StdErr   = "imagew.exe timed out after ${TimeoutSeconds}s"
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

function ConvertTo-FoCompareNormalizedImageViaFfmpeg {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [Parameter(Mandatory)]
        [string]$FfmpegExe,
        [string]$WorkingDirectory
    )

    $result = Invoke-FoFfmpegCli -FfmpegExe $FfmpegExe -WorkingDirectory $WorkingDirectory -ArgumentList @(
        '-y'
        '-loglevel', 'error'
        '-i', $InputPath
        '-pix_fmt', 'rgba'
        $OutputPath
    )

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) {
        $detail = if ($result.StdErr) { $result.StdErr } else { "exit code $($result.ExitCode)" }
        throw "ffmpeg failed to normalize '$InputPath' for compare: $detail"
    }
}

function ConvertTo-FoCompareNormalizedImageViaImagew {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [Parameter(Mandatory)]
        [string]$ImagewExe,
        [string]$WorkingDirectory
    )

    $result = Invoke-FoImagewCli -ImagewExe $ImagewExe -WorkingDirectory $WorkingDirectory -ArgumentList @(
        $InputPath
        $OutputPath
    )

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) {
        $detail = if ($result.StdErr) { $result.StdErr } else { "exit code $($result.ExitCode)" }
        throw "imagew failed to normalize '$InputPath' for compare: $detail"
    }
}

function ConvertTo-FoCompareNormalizedImageForCompare {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [ValidateSet('Auto', 'Magick', 'Ffmpeg', 'Imagew')]
        [string]$Method = 'Auto',
        [Parameter(Mandatory)]
        [string]$MagickExe,
        [string]$FfmpegExe,
        [string]$ImagewExe,
        [string]$WorkingDirectory
    )

    $useBmpFallback = ($Method -in @('Auto', 'Ffmpeg', 'Imagew')) -and (Test-FoCompareBmpPath -Path $InputPath)

    if ($Method -eq 'Magick' -or (-not $useBmpFallback -and $Method -eq 'Auto')) {
        ConvertTo-FoCompareNormalizedImage -InputPath $InputPath -OutputPath $OutputPath `
            -MagickExe $MagickExe -WorkingDirectory $WorkingDirectory
        return 'Magick'
    }

    if ($Method -eq 'Imagew') {
        ConvertTo-FoCompareNormalizedImageViaImagew -InputPath $InputPath -OutputPath $OutputPath `
            -ImagewExe $ImagewExe -WorkingDirectory $WorkingDirectory
        return 'Imagew'
    }

    try {
        ConvertTo-FoCompareNormalizedImageViaFfmpeg -InputPath $InputPath -OutputPath $OutputPath `
            -FfmpegExe $FfmpegExe -WorkingDirectory $WorkingDirectory
        return 'Ffmpeg'
    }
    catch {
        if ($Method -eq 'Ffmpeg') {
            throw
        }

        ConvertTo-FoCompareNormalizedImageViaImagew -InputPath $InputPath -OutputPath $OutputPath `
            -ImagewExe $ImagewExe -WorkingDirectory $WorkingDirectory
        return 'Imagew'
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

function Invoke-FoCompareNormalizedImages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BeforeNorm,
        [Parameter(Mandatory)]
        [string]$AfterNorm,
        [Parameter(Mandatory)]
        [string]$MagickExe,
        [string]$WorkingDirectory,
        [ValidateSet('Pixel', 'SSIM')]
        [string]$Mode = 'Pixel',
        [double]$SSIMDissimilarityMaximum = 0,
        [string]$DiffOutputPath
    )

    $metricName = if ($Mode -eq 'Pixel') { 'AE' } else { 'SSIM' }
    $compareArgs = @(
        'compare'
        '-define', 'compare:virtual-pixels=false'
        '-metric', $metricName
        $BeforeNorm
        $AfterNorm
        'null:'
    )

    $compareResult = Invoke-FoMagickCli -MagickExe $MagickExe -WorkingDirectory $WorkingDirectory -ArgumentList $compareArgs
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
        $null = Invoke-FoMagickCli -MagickExe $MagickExe -WorkingDirectory $WorkingDirectory -ArgumentList @(
            'compare'
            '-compose', 'src'
            $BeforeNorm
            $AfterNorm
            '-highlight-color', 'red'
            '-lowlight-color', 'white'
            $DiffOutputPath
        )
        if (Test-Path -LiteralPath $DiffOutputPath) {
            $diffPath = $DiffOutputPath
        }
    }

    return [PSCustomObject]@{
        Pass        = $pass
        Metric      = $metricDisplay
        MetricValue = $metricValue
        DiffPath    = $diffPath
    }
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
        [double]$PngDssimDissimilarityMaximum = 0,
        [switch]$AllowMissingDssim,
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

    $isPngCompare = (Test-FoComparePngPath -Path $Before) -and (Test-FoComparePngPath -Path $After)
    if ($isPngCompare -and $Mode -eq 'Pixel') {
        $dssimExe = Get-FoCompareDssimPathOptional -PluginPath $PluginPath
        if ($dssimExe) {
            return Compare-FoImageViaDssim -Before $Before -After $After -DssimExe $dssimExe `
                -DissimilarityMaximum $PngDssimDissimilarityMaximum -MagickPath $MagickPath `
                -PluginPath $PluginPath -DiffOutputPath $DiffOutputPath
        }

        Assert-FoDssimCompareAvailable -PluginPath $PluginPath -AllowMissingDssim:$AllowMissingDssim
    }

    $magick = Get-FoCompareMagickPath -MagickPath $MagickPath -PluginPath $PluginPath
    $ffmpeg = Get-FoCompareFfmpegPath -PluginPath $PluginPath
    $imagew = Get-FoCompareImagewPath -PluginPath $PluginPath
    $workDir = Split-Path -Parent $magick
    $tempDir = [System.IO.Path]::GetTempPath()
    $token = "FoCompare_$(Get-Random)"
    $beforeNorm = Join-Path $tempDir "${token}_before.png"
    $afterNorm = Join-Path $tempDir "${token}_after.png"
    $isBmpCompare = (Test-FoCompareBmpPath -Path $Before) -or (Test-FoCompareBmpPath -Path $After)

    try {
        $normalizeParams = @{
            MagickExe         = $magick
            FfmpegExe         = $ffmpeg
            ImagewExe         = $imagew
            WorkingDirectory  = $workDir
            Method            = 'Auto'
        }

        $beforeMethod = ConvertTo-FoCompareNormalizedImageForCompare -InputPath $Before -OutputPath $beforeNorm @normalizeParams
        $afterMethod = ConvertTo-FoCompareNormalizedImageForCompare -InputPath $After -OutputPath $afterNorm @normalizeParams

        $compareParams = @{
            BeforeNorm                 = $beforeNorm
            AfterNorm                  = $afterNorm
            MagickExe                  = $magick
            WorkingDirectory           = $workDir
            Mode                       = $Mode
            SSIMDissimilarityMaximum   = $SSIMDissimilarityMaximum
            DiffOutputPath             = $DiffOutputPath
        }
        $compare = Invoke-FoCompareNormalizedImages @compareParams

        if ($isBmpCompare -and $Mode -eq 'Pixel' -and -not $compare.Pass `
                -and ($beforeMethod -eq 'Ffmpeg' -or $afterMethod -eq 'Ffmpeg')) {
            $normalizeParams['Method'] = 'Imagew'
            ConvertTo-FoCompareNormalizedImageForCompare -InputPath $Before -OutputPath $beforeNorm @normalizeParams | Out-Null
            ConvertTo-FoCompareNormalizedImageForCompare -InputPath $After -OutputPath $afterNorm @normalizeParams | Out-Null
            $compare = Invoke-FoCompareNormalizedImages @compareParams
        }

        $beforeInfo = $null
        try {
            $beforeInfo = Get-FoImageInfo -Path $Before -MagickPath $magick -PluginPath $PluginPath
        }
        catch {
            $beforeInfo = Get-FoImageInfo -Path $beforeNorm -MagickPath $magick -PluginPath $PluginPath
        }

        return [PSCustomObject]@{
            Pass        = $compare.Pass
            Mode        = $Mode
            Metric      = $compare.Metric
            MetricValue = $compare.MetricValue
            DiffPath    = $compare.DiffPath
            Width       = $beforeInfo.Width
            Height      = $beforeInfo.Height
            BeforePath  = $Before
            AfterPath   = $After
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
