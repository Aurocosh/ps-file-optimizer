$global:FoImageTestFixtureRoot = Join-Path $global:FoTestSupportRoot 'Fixtures\Images'

function Get-FoImageTestCorpusRoot {
    [CmdletBinding()]
    param(
        [string]$Override
    )

    if ($Override) {
        return [System.IO.Path]::GetFullPath($Override)
    }
    if ($env:FO_TEST_CORPUS_PATH) {
        return [System.IO.Path]::GetFullPath($env:FO_TEST_CORPUS_PATH)
    }
    return Join-Path $global:FoTestSupportRoot 'Fixtures\Corpus'
}

function Get-FoImageTestManifest {
    [CmdletBinding()]
    param()

    Import-FoDataFile -Path (Join-Path $global:FoTestSupportRoot 'ImageTestManifest.psd1')
}

function Get-FoImageTestFixtureEntry {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'ById', Mandatory)]
        [string]$Id,
        [Parameter(ParameterSetName = 'BySource', Mandatory)]
        [string]$Source
    )

    $manifest = Get-FoImageTestManifest
    $files = @($manifest.Tiers.A.Files)
    if (-not $files) {
        throw 'Image test manifest has no Tier A files.'
    }

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $entry = $files | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
        if (-not $entry) {
            throw "Unknown image test fixture id '$Id'."
        }
        return $entry
    }

    $normalized = $Source -replace '\\', '/'
    $entry = $files | Where-Object { ($_.Source -replace '\\', '/') -eq $normalized } | Select-Object -First 1
    if (-not $entry) {
        throw "Unknown image test fixture source '$Source'."
    }
    return $entry
}

function Get-FoImageTestFixturePath {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'ById')]
        [string]$Id,
        [Parameter(ParameterSetName = 'BySource')]
        [string]$Source,
        [Parameter(ParameterSetName = 'ByPath', Mandatory)]
        [string]$Path
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
        $full = if ([System.IO.Path]::IsPathRooted($Path)) {
            [System.IO.Path]::GetFullPath($Path)
        }
        else {
            [System.IO.Path]::GetFullPath((Join-Path $global:FoImageTestFixtureRoot $Path))
        }
        if (-not (Test-Path -LiteralPath $full)) {
            throw "Image test fixture not found: $full"
        }
        return $full
    }

    $entry = if ($Id) {
        Get-FoImageTestFixtureEntry -Id $Id
    }
    else {
        Get-FoImageTestFixtureEntry -Source $Source
    }

    return Get-FoImageTestFixturePath -Path $entry.Source
}

function Test-FoImageTestFixturesPresent {
    [CmdletBinding()]
    param(
        [ValidateSet('A', 'B', 'C', 'D')]
        [string]$Tier = 'A',
        [string]$CorpusRoot
    )

    if ($Tier -eq 'A') {
        $manifest = Get-FoImageTestManifest
        $missing = @()
        foreach ($entry in @($manifest.Tiers.A.Files)) {
            $path = Join-Path $global:FoImageTestFixtureRoot ($entry.Source -replace '/', [System.IO.Path]::DirectorySeparatorChar)
            if (-not (Test-Path -LiteralPath $path)) {
                $missing += $entry.Source
            }
        }

        return @{
            Tier    = $Tier
            Present = ($missing.Count -eq 0)
            Missing = $missing
            Count   = @($manifest.Tiers.A.Files).Count
        }
    }

    $manifest = Get-FoImageTestManifest
    if (-not $manifest.AuxReleases -or -not $manifest.AuxReleases[$Tier]) {
        throw "No AuxReleases metadata for Tier $Tier."
    }

    $root = Get-FoImageTestCorpusRoot -Override $CorpusRoot
    $tierDir = Join-Path $root ("tier-$($Tier.ToLower())")
    $fileCount = 0
    if (Test-Path -LiteralPath $tierDir) {
        $fileCount = @(Get-ChildItem -LiteralPath $tierDir -Recurse -File -ErrorAction SilentlyContinue).Count
    }

    $expected = $manifest.AuxReleases[$Tier].FileCount
    $present = $fileCount -gt 0
    if ($expected -and $fileCount -ne $expected) {
        $present = $false
    }

    return @{
        Tier     = $Tier
        Present  = $present
        Missing  = if ($present) { @() } else { @("tier-$($Tier.ToLower()) under $root") }
        Count    = $fileCount
        Expected = $expected
        Root     = $tierDir
    }
}

function Get-FoImageTestProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$PluginPath
    )

    $profiles = Import-FoDataFile -Path (Join-Path $global:FoTestSupportRoot 'ImageTestProfiles.psd1')
    if (-not $profiles.ContainsKey($Name)) {
        throw "Unknown image test profile '$Name'."
    }

    $bound = @{}
    foreach ($key in $profiles[$Name].Keys) {
        $bound[$key] = $profiles[$Name][$key]
    }

    if ($PluginPath) {
        $bound['PluginPath'] = $PluginPath
    }
    elseif (Get-Command Get-FoTestPluginPath -ErrorAction SilentlyContinue) {
        $bound['PluginPath'] = Get-FoTestPluginPath
    }

    if (-not $bound['PluginPath']) {
        $bound['PluginSearchMode'] = 'PortableOnly'
    }
    else {
        $bound['PluginSearchMode'] = 'PortableOnly'
    }

    Merge-FoSettings -BoundParameters $bound
}

function Copy-FoImageFixture {
    [CmdletBinding()]
    param(
        [string]$Id,
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$Destination
    )

    if (-not $Id -and -not $Source) {
        throw 'Specify -Id or -Source.'
    }

    $fixturePath = if ($Id) {
        Get-FoImageTestFixturePath -Id $Id
    }
    else {
        Get-FoImageTestFixturePath -Source $Source
    }

    $destDir = Split-Path -Parent $Destination
    if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Copy-Item -LiteralPath $fixturePath -Destination $Destination -Force
    return ([System.IO.Path]::GetFullPath($Destination))
}

function Invoke-FoImageOptimizationTest {
    [CmdletBinding()]
    param(
        [string]$FixtureId,
        [string]$FixturePath,
        [Parameter(Mandatory)]
        [hashtable]$Settings,
        [ValidateSet('Pixel', 'SSIM', 'SSIMOnly')]
        [string]$CompareMode = 'Pixel',
        [string]$WorkDirectory,
        [string]$DiffOutputPath,
        [double]$SSIMDissimilarityMaximum = -1,
        [switch]$SkipCompare
    )

    if (-not $FixtureId -and -not $FixturePath) {
        throw 'Specify -FixtureId or -FixturePath.'
    }

    $entry = $null
    if ($FixtureId) {
        $entry = Get-FoImageTestFixtureEntry -Id $FixtureId
        $FixturePath = Get-FoImageTestFixturePath -Id $FixtureId
    }
    else {
        $FixturePath = [System.IO.Path]::GetFullPath($FixturePath)
        if (-not (Test-Path -LiteralPath $FixturePath)) {
            throw "FixturePath not found: $FixturePath"
        }
    }

    $workRoot = if ($WorkDirectory) {
        [System.IO.Path]::GetFullPath($WorkDirectory)
    }
    elseif ($TestDrive) {
        Join-Path $TestDrive 'fo-image-test'
    }
    else {
        Join-Path $env:TEMP ("FoImageTest_{0}" -f (Get-Random))
    }

    if (-not (Test-Path -LiteralPath $workRoot)) {
        New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
    }

    $fileName = [System.IO.Path]::GetFileName($FixturePath)
    $inputDir = Join-Path $workRoot 'input'
    if (-not (Test-Path -LiteralPath $inputDir)) {
        New-Item -ItemType Directory -Path $inputDir -Force | Out-Null
    }
    $inputPath = Join-Path $inputDir $fileName
    $beforePath = Join-Path $workRoot ("before_{0}" -f $fileName)

    Copy-Item -LiteralPath $FixturePath -Destination $inputPath -Force
    Copy-Item -LiteralPath $FixturePath -Destination $beforePath -Force

    $optimization = Invoke-FoPluginChain -Path $inputPath -Settings $Settings

    $afterPath = if ($optimization.Status -eq 'Optimized') {
        $optimization.OutputPath
    }
    else {
        $inputPath
    }

    $compare = $null
    $pass = $optimization.Status -in @('Optimized', 'Unchanged')

    if (-not $SkipCompare -and $pass) {
        $compareModeEffective = if ($CompareMode -eq 'SSIMOnly') { 'SSIM' } else { $CompareMode }
        $compareParams = @{
            Before     = $beforePath
            After      = $afterPath
            Mode       = $compareModeEffective
            PluginPath = $Settings.PluginPath
        }
        if ($PSBoundParameters.ContainsKey('DiffOutputPath') -and $DiffOutputPath) {
            $compareParams['DiffOutputPath'] = $DiffOutputPath
        }
        if ($compareModeEffective -eq 'SSIM' -and $SSIMDissimilarityMaximum -ge 0) {
            $compareParams['SSIMDissimilarityMaximum'] = $SSIMDissimilarityMaximum
        }

        $compare = Compare-FoImage @compareParams

        if ($CompareMode -eq 'Pixel' -and -not $compare.Pass) {
            $ext = [System.IO.Path]::GetExtension($afterPath)
            if ($ext -match '(?i)^\.jpe?g$') {
                $jpegCompare = Test-FoJpegImageCompare -Before $beforePath -After $afterPath `
                    -PluginPath $Settings.PluginPath -SSIMDissimilarityMaximum $SSIMDissimilarityMaximum
                $compare = $jpegCompare.Compare
                $CompareMode = $jpegCompare.CompareMode
            }
        }

        $pass = $compare.Pass
    }

    $decode = $null
    if ($pass -and -not $SkipCompare) {
        try {
            $decode = Get-FoImageInfo -Path $afterPath -PluginPath $Settings.PluginPath
        }
        catch {
            $pass = $false
        }
    }

    return [PSCustomObject]@{
        FixtureId    = if ($entry) { $entry.Id } else { $null }
        FixturePath  = $FixturePath
        BeforePath   = $beforePath
        AfterPath    = $afterPath
        Optimization = $optimization
        Compare      = $compare
        CompareMode  = if ($CompareMode -eq 'SSIMOnly') { 'SSIMOnly' } else { $CompareMode }
        Decode       = $decode
        Pass         = $pass
    }
}

function Get-FoImageTestLossyThreshold {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,
        [ValidateSet('Default', 'JPEG', 'PNG', 'GIF', 'WebP', 'APNG', 'AVIF', 'BMP', 'ICO', 'TIFF')]
        [string]$Format = 'Default'
    )

    $profiles = Import-FoDataFile -Path (Join-Path $global:FoTestSupportRoot 'ImageTestProfiles.psd1')
    if (-not $profiles.ContainsKey($ProfileName)) {
        throw "Unknown image test profile '$ProfileName'."
    }

    $profile = $profiles[$ProfileName]
    if (-not $profile.SSIMDissimilarityMaximum) {
        throw "Profile '$ProfileName' has no SSIMDissimilarityMaximum thresholds."
    }

    $thresholds = $profile.SSIMDissimilarityMaximum
    if ($thresholds.ContainsKey($Format)) {
        return [double]$thresholds[$Format]
    }

    return [double]$thresholds.Default
}

function Invoke-FoLossyImageOptimizationTest {
    [CmdletBinding()]
    param(
        [string]$FixtureId,
        [string]$FixturePath,
        [string]$ProfileName = 'LossyHighQuality',
        [ValidateSet('Default', 'JPEG', 'PNG', 'GIF', 'WebP', 'APNG', 'AVIF', 'BMP', 'ICO', 'TIFF')]
        [string]$Format = 'Default',
        [string]$WorkDirectory,
        [string]$DiffOutputPath,
        [hashtable]$Settings
    )

    if (-not $Settings) {
        $pluginPath = if (Get-Command Get-FoTestPluginPath -ErrorAction SilentlyContinue) {
            Get-FoTestPluginPath
        }
        $Settings = Get-FoImageTestProfile -Name $ProfileName -PluginPath $pluginPath
    }

    $threshold = Get-FoImageTestLossyThreshold -ProfileName $ProfileName -Format $Format
    $params = @{
        Settings                   = $Settings
        CompareMode                = 'SSIMOnly'
        SSIMDissimilarityMaximum   = $threshold
        WorkDirectory              = $WorkDirectory
    }
    if ($FixtureId) { $params['FixtureId'] = $FixtureId }
    if ($FixturePath) { $params['FixturePath'] = $FixturePath }
    if ($DiffOutputPath) { $params['DiffOutputPath'] = $DiffOutputPath }

    return Invoke-FoImageOptimizationTest @params
}

function Assert-FoLossyOptimizationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Result,
        [double]$SSIMDissimilarityMaximum
    )

    @('Optimized', 'Unchanged') -contains $Result.Optimization.Status | Should -Be $true

    if ($Result.Optimization.Status -eq 'Optimized') {
        ($Result.Optimization.FinalSize -le $Result.Optimization.OriginalSize) | Should -Be $true
    }

    $Result.CompareMode | Should -Be 'SSIMOnly'
    $Result.Compare.Pass | Should -Be $true
    ($Result.Compare.MetricValue -le $SSIMDissimilarityMaximum) | Should -Be $true
    $Result.Pass | Should -Be $true
}

function Assert-FoImageOptimizationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Result,
        [switch]$RequireCompare,
        [switch]$RequireSizeReduction
    )

    @('Optimized', 'Unchanged') -contains $Result.Optimization.Status | Should -Be $true

    if ($RequireSizeReduction -and $Result.Optimization.Status -eq 'Optimized') {
        ($Result.Optimization.FinalSize -lt $Result.Optimization.OriginalSize) | Should -Be $true
    }

    if ($Result.Decode) {
        ($Result.Decode.Width -gt 0) | Should -Be $true
        ($Result.Decode.Height -gt 0) | Should -Be $true
    }

    if ($RequireCompare) {
        $Result.Compare.Pass | Should -Be $true
        $Result.Pass | Should -Be $true
    }
}

function Get-FoGifFrameCount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$PluginPath
    )

    $magick = Get-FoCompareMagickPath -PluginPath $PluginPath
    $workDir = Split-Path -Parent $magick
    $result = Invoke-FoMagickCli -MagickExe $magick -WorkingDirectory $workDir -ArgumentList @(
        'identify'
        '-ping'
        '-format'
        '%p\n'
        $Path
    )

    if ($result.ExitCode -ne 0) {
        throw "magick identify failed for GIF '$Path': $($result.StdErr)"
    }

    $frames = @($result.StdOut -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $count = $frames.Count
    if ($count -lt 1) {
        throw "Could not determine GIF frame count for '$Path'."
    }

    return $count
}

function Compare-FoGifFrames {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Before,
        [Parameter(Mandatory)]
        [string]$After,
        [string]$PluginPath,
        [string]$WorkDirectory
    )

    $beforeCount = Get-FoGifFrameCount -Path $Before -PluginPath $PluginPath
    $afterCount = Get-FoGifFrameCount -Path $After -PluginPath $PluginPath

    if ($beforeCount -ne $afterCount) {
        return [PSCustomObject]@{
            Pass        = $false
            BeforeCount = $beforeCount
            AfterCount  = $afterCount
            FrameResults = @()
            Reason      = "Frame count mismatch: before=$beforeCount after=$afterCount"
        }
    }

    $workRoot = if ($WorkDirectory) {
        [System.IO.Path]::GetFullPath($WorkDirectory)
    }
    else {
        Join-Path $env:TEMP ("FoGifCompare_{0}" -f (Get-Random))
    }
    if (-not (Test-Path -LiteralPath $workRoot)) {
        New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
    }

    $magick = Get-FoCompareMagickPath -PluginPath $PluginPath
    $workDir = Split-Path -Parent $magick
    $frameResults = @()
    $pass = $true

    for ($i = 0; $i -lt $beforeCount; $i++) {
        $beforeFrame = Join-Path $workRoot ("before-frame-{0}.png" -f $i)
        $afterFrame = Join-Path $workRoot ("after-frame-{0}.png" -f $i)

        foreach ($pair in @(
                @{ Source = $Before; Dest = $beforeFrame; Label = 'before' }
                @{ Source = $After; Dest = $afterFrame; Label = 'after' }
            )) {
            $extract = Invoke-FoMagickCli -MagickExe $magick -WorkingDirectory $workDir -ArgumentList @(
                ('{0}[{1}]' -f $pair.Source, $i)
                '-alpha'
                'on'
                ('PNG32:{0}' -f $pair.Dest)
            )
            if ($extract.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $pair.Dest)) {
                throw "Failed to extract GIF frame $i ($($pair.Label)): $($extract.StdErr)"
            }
        }

        $compare = Compare-FoImage -Before $beforeFrame -After $afterFrame -Mode Pixel -PluginPath $PluginPath
        $frameResults += [PSCustomObject]@{
            FrameIndex  = $i
            Pass        = $compare.Pass
            MetricValue = $compare.MetricValue
        }
        if (-not $compare.Pass) { $pass = $false }
    }

    return [PSCustomObject]@{
        Pass         = $pass
        BeforeCount  = $beforeCount
        AfterCount   = $afterCount
        FrameResults = $frameResults
        Reason       = if ($pass) { $null } else { 'One or more frames differ' }
    }
}

function Test-FoJpegImageCompare {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Before,
        [Parameter(Mandatory)]
        [string]$After,
        [string]$PluginPath,
        [double]$SSIMDissimilarityMaximum = -1
    )

    $compare = Compare-FoImage -Before $Before -After $After -Mode Pixel -PluginPath $PluginPath
    $mode = 'Pixel'

    if (-not $compare.Pass) {
        $max = if ($SSIMDissimilarityMaximum -ge 0) {
            $SSIMDissimilarityMaximum
        }
        else {
            (Get-FoImageTestDecisions).JpegSSIMFallbackMaximum
        }
        $compare = Compare-FoImage -Before $Before -After $After -Mode SSIM `
            -PluginPath $PluginPath -SSIMDissimilarityMaximum $max
        $mode = 'SSIM'
    }

    return [PSCustomObject]@{
        Pass        = $compare.Pass
        Compare     = $compare
        CompareMode = $mode
    }
}

function Get-FoFfmpegPath {
    [CmdletBinding()]
    param([string]$PluginPath)

    $resolved = Resolve-FoPluginExecutable -Name 'ffmpeg.exe' -SearchMode PortableFirst -PluginPath $PluginPath
    if (-not $resolved.Found) {
        throw 'ffmpeg.exe not found. Set FO_TEST_PLUGIN_PATH or pass -PluginPath.'
    }
    return $resolved.Path
}

function Get-FoApngFrameCount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$PluginPath,
        [string]$WorkDirectory
    )

    $workRoot = if ($WorkDirectory) {
        [System.IO.Path]::GetFullPath($WorkDirectory)
    }
    else {
        Join-Path $env:TEMP ("FoApngCount_{0}" -f (Get-Random))
    }
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

    $ffmpeg = Get-FoFfmpegPath -PluginPath $PluginPath
    $pattern = Join-Path $workRoot 'frame_%04d.png'
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ffmpeg
    $psi.Arguments = "-y -loglevel error -i `"$Path`" `"$pattern`""
    $psi.WorkingDirectory = Split-Path -Parent $ffmpeg
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::Start($psi)
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "ffmpeg failed extracting APNG frames from '$Path': $($process.StandardError.ReadToEnd())"
    }

    $count = @(Get-ChildItem -LiteralPath $workRoot -Filter 'frame_*.png').Count
    if ($count -lt 1) {
        throw "No frames extracted from APNG '$Path'."
    }

    return $count
}

function Compare-FoApngFrames {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Before,
        [Parameter(Mandatory)]
        [string]$After,
        [string]$PluginPath,
        [string]$WorkDirectory
    )

    $workRoot = if ($WorkDirectory) {
        [System.IO.Path]::GetFullPath($WorkDirectory)
    }
    else {
        Join-Path $env:TEMP ("FoApngCompare_{0}" -f (Get-Random))
    }
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

    $beforeDir = Join-Path $workRoot 'before'
    $afterDir = Join-Path $workRoot 'after'
    New-Item -ItemType Directory -Path $beforeDir, $afterDir -Force | Out-Null

    $beforeCount = Get-FoApngFrameCount -Path $Before -PluginPath $PluginPath -WorkDirectory $beforeDir
    $afterCount = Get-FoApngFrameCount -Path $After -PluginPath $PluginPath -WorkDirectory $afterDir

    if ($beforeCount -ne $afterCount) {
        return [PSCustomObject]@{
            Pass         = $false
            BeforeCount  = $beforeCount
            AfterCount   = $afterCount
            FrameResults = @()
            Reason       = "Frame count mismatch: before=$beforeCount after=$afterCount"
        }
    }

    $frameResults = @()
    $pass = $true
    for ($i = 1; $i -le $beforeCount; $i++) {
        $beforeFrame = Join-Path $beforeDir ("frame_{0:D4}.png" -f $i)
        $afterFrame = Join-Path $afterDir ("frame_{0:D4}.png" -f $i)
        $compare = Compare-FoImage -Before $beforeFrame -After $afterFrame -Mode Pixel -PluginPath $PluginPath
        $frameResults += [PSCustomObject]@{
            FrameIndex  = $i - 1
            Pass        = $compare.Pass
            MetricValue = $compare.MetricValue
        }
        if (-not $compare.Pass) { $pass = $false }
    }

    return [PSCustomObject]@{
        Pass         = $pass
        BeforeCount  = $beforeCount
        AfterCount   = $afterCount
        FrameResults = $frameResults
        Reason       = if ($pass) { $null } else { 'One or more APNG frames differ' }
    }
}

function Get-FoIcoEmbeddedEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$PluginPath
    )

    $magick = Get-FoCompareMagickPath -PluginPath $PluginPath
    $workDir = Split-Path -Parent $magick
    $result = Invoke-FoMagickCli -MagickExe $magick -WorkingDirectory $workDir -ArgumentList @(
        'identify'
        '-ping'
        '-format'
        '%w %h %p\n'
        $Path
    )

    if ($result.ExitCode -ne 0) {
        throw "magick identify failed for ICO '$Path': $($result.StdErr)"
    }

    $entries = @()
    foreach ($line in @($result.StdOut -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        $parts = $line -split '\s+'
        if ($parts.Count -lt 3) { continue }
        $entries += [PSCustomObject]@{
            Index  = [int]$parts[2]
            Width  = [int]$parts[0]
            Height = [int]$parts[1]
            Area   = [int]$parts[0] * [int]$parts[1]
        }
    }

    if ($entries.Count -eq 0) {
        throw "No embedded images found in ICO '$Path'."
    }

    return $entries
}

function Get-FoIcoLargestIndex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$PluginPath
    )

    $entries = Get-FoIcoEmbeddedEntries -Path $Path -PluginPath $PluginPath
    return ($entries | Sort-Object -Property Area, Index -Descending | Select-Object -First 1).Index
}

function Compare-FoIcoLargest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Before,
        [Parameter(Mandatory)]
        [string]$After,
        [string]$PluginPath,
        [string]$WorkDirectory
    )

    $beforeIndex = Get-FoIcoLargestIndex -Path $Before -PluginPath $PluginPath
    $afterIndex = Get-FoIcoLargestIndex -Path $After -PluginPath $PluginPath

    if ($beforeIndex -ne $afterIndex) {
        return [PSCustomObject]@{
            Pass        = $false
            BeforeIndex = $beforeIndex
            AfterIndex  = $afterIndex
            Compare     = $null
            Reason      = "Largest icon index mismatch: before=$beforeIndex after=$afterIndex"
        }
    }

    $workRoot = if ($WorkDirectory) {
        [System.IO.Path]::GetFullPath($WorkDirectory)
    }
    else {
        Join-Path $env:TEMP ("FoIcoCompare_{0}" -f (Get-Random))
    }
    if (-not (Test-Path -LiteralPath $workRoot)) {
        New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
    }

    $magick = Get-FoCompareMagickPath -PluginPath $PluginPath
    $workDir = Split-Path -Parent $magick
    $beforePng = Join-Path $workRoot 'before-largest.png'
    $afterPng = Join-Path $workRoot 'after-largest.png'

    foreach ($pair in @(
            @{ Source = $Before; Index = $beforeIndex; Dest = $beforePng }
            @{ Source = $After; Index = $afterIndex; Dest = $afterPng }
        )) {
        $extract = Invoke-FoMagickCli -MagickExe $magick -WorkingDirectory $workDir -ArgumentList @(
            ('{0}[{1}]' -f $pair.Source, $pair.Index)
            '-alpha'
            'on'
            ('PNG32:{0}' -f $pair.Dest)
        )
        if ($extract.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $pair.Dest)) {
            throw "Failed to extract ICO index $($pair.Index): $($extract.StdErr)"
        }
    }

    $compare = Compare-FoImage -Before $beforePng -After $afterPng -Mode Pixel -PluginPath $PluginPath
    return [PSCustomObject]@{
        Pass        = $compare.Pass
        BeforeIndex = $beforeIndex
        AfterIndex  = $afterIndex
        Compare     = $compare
        Reason      = if ($compare.Pass) { $null } else { 'Largest embedded icon differs' }
    }
}
