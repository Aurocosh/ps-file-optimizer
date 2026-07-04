$script:FoImageTestFixtureRoot = Join-Path $PSScriptRoot 'Fixtures\Images'

function Get-FoImageTestManifest {
    [CmdletBinding()]
    param()

    Import-FoDataFile -Path (Join-Path $PSScriptRoot 'ImageTestManifest.psd1')
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
            [System.IO.Path]::GetFullPath((Join-Path $script:FoImageTestFixtureRoot $Path))
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
        [ValidateSet('A')]
        [string]$Tier = 'A'
    )

    if ($Tier -ne 'A') {
        throw "Only Tier A fixture presence checks are implemented."
    }

    $manifest = Get-FoImageTestManifest
    $missing = @()
    foreach ($entry in @($manifest.Tiers.A.Files)) {
        $path = Join-Path $script:FoImageTestFixtureRoot ($entry.Source -replace '/', [System.IO.Path]::DirectorySeparatorChar)
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

function Get-FoImageTestProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$PluginPath
    )

    $profiles = Import-FoDataFile -Path (Join-Path $PSScriptRoot 'ImageTestProfiles.psd1')
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
    $inputPath = Join-Path $workRoot $fileName
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
        $compareParams = @{
            Before     = $beforePath
            After      = $afterPath
            Mode       = $CompareMode
            PluginPath = $Settings.PluginPath
        }
        if ($PSBoundParameters.ContainsKey('DiffOutputPath') -and $DiffOutputPath) {
            $compareParams['DiffOutputPath'] = $DiffOutputPath
        }
        if ($CompareMode -match 'SSIM' -and $SSIMDissimilarityMaximum -ge 0) {
            $compareParams['SSIMDissimilarityMaximum'] = $SSIMDissimilarityMaximum
        }

        $compare = Compare-FoImage @compareParams

        if ($CompareMode -eq 'Pixel' -and -not $compare.Pass) {
            $ext = [System.IO.Path]::GetExtension($afterPath)
            if ($ext -match '(?i)^\.jpe?g$') {
                $decisions = Get-FoImageTestDecisions
                $fallbackMax = $decisions.JpegSSIMFallbackMaximum
                if ($null -ne $fallbackMax) {
                    $compare = Compare-FoImage -Before $beforePath -After $afterPath -Mode SSIM `
                        -PluginPath $Settings.PluginPath -SSIMDissimilarityMaximum $fallbackMax
                    $CompareMode = 'SSIM'
                }
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
        CompareMode  = $CompareMode
        Decode       = $decode
        Pass         = $pass
    }
}
