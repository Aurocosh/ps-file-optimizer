#Requires -Version 5.1
<#
.SYNOPSIS
  Batch-optimize image corpus fixtures and export compare metrics to CSV.

.DESCRIPTION
  L3 regression helper (tagged Slow in Pester). Runs Invoke-FoImageOptimizationTest
  across Tier A manifest fixtures or all image files under a downloaded Tier B/C/D corpus.

.PARAMETER Tier
  A — manifest fixtures under Tests/Fixtures/Images/.
  B, C, D — recursive scan under Tests/Fixtures/Corpus/tier-{b,c,d}/ (download via Get-ImageTestCorpus.ps1).

.PARAMETER ProfileName
  Settings profile from Tests/ImageTestProfiles.psd1.

.PARAMETER OutputCsv
  CSV path for results. Default: ./corpus-sweep-tier{tier}-{profile}-{timestamp}.csv under current directory.

.PARAMETER SkipCompare
  Size-only regression; skip visual compare.

.PARAMETER AllowMissingDssim
  Allow PNG pixel compare to fall back to ImageMagick AE when dssim is not installed.
  Default: require dssim (also opt out with FO_COMPARE_ALLOW_MISSING_DSSIM=1).

.PARAMETER MaxFiles
  Limit files processed (0 = all). Useful for smoke runs.

.EXAMPLE
  .\Scripts\Invoke-FoImageCorpusSweep.ps1 -Tier A -ProfileName LosslessDefault

.EXAMPLE
  .\Scripts\Get-ImageTestCorpus.ps1 -Tier B
  .\Scripts\Invoke-FoImageCorpusSweep.ps1 -Tier B -MaxFiles 20 -OutputCsv .\tier-b-sweep.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('A', 'B', 'C', 'D')]
    [string]$Tier,
    [string]$ProfileName = 'LosslessDefault',
    [string]$OutputCsv,
    [string]$PluginPath,
    [ValidateSet('Pixel', 'SSIM', 'SSIMOnly')]
    [string]$CompareMode = 'Pixel',
    [switch]$SkipCompare,
    [switch]$AllowMissingDssim,
    [int]$MaxFiles = 0,
    [string]$CorpusRoot,
    [string]$WorkDirectory
)

$ErrorActionPreference = 'Stop'

$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force
Import-Module (Join-Path $moduleRoot 'Tests\FoTestSupport\FoTestSupport.psd1') -Force

if (-not (Test-FoPluginsAvailable)) {
    throw 'Plugin binaries required. Set FO_TEST_PLUGIN_PATH or install plugins under .\plugins\.'
}

$resolvedPluginPath = if ($PluginPath) {
    [System.IO.Path]::GetFullPath($PluginPath)
}
else {
    Get-FoTestPluginPath
}

Write-FoTestPluginVersions -PluginPath $resolvedPluginPath -Verbose

if (-not $SkipCompare -and $CompareMode -eq 'Pixel' -and -not (Test-FoCompareAllowMissingDssim -AllowMissingDssim:$AllowMissingDssim.IsPresent)) {
    Assert-FoDssimCompareAvailable -PluginPath $resolvedPluginPath
}

$settings = Get-FoImageTestProfile -Name $ProfileName -PluginPath $resolvedPluginPath
$imageExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.tif', '.tiff', '.ico', '.avif')

function Get-FoCorpusSweepTargets {
    param(
        [string]$TierName,
        [string]$RootOverride
    )

    $targets = @()

    if ($TierName -eq 'A') {
        $manifest = Get-FoImageTestManifest
        foreach ($entry in @($manifest.Tiers.A.Files)) {
            $targets += [PSCustomObject]@{
                Id           = $entry.Id
                RelativePath = $entry.Source
                Format       = $entry.Format
                Path         = Get-FoImageTestFixturePath -Id $entry.Id
            }
        }
        return $targets
    }

    $presence = Test-FoImageTestFixturesPresent -Tier $TierName -CorpusRoot $RootOverride
    if (-not $presence.Present) {
        throw "Tier $TierName corpus not present at '$($presence.Root)'. Run Get-ImageTestCorpus.ps1 -Tier $TierName first."
    }

    $tierRoot = $presence.Root
    foreach ($file in Get-ChildItem -LiteralPath $tierRoot -Recurse -File) {
        if ($imageExtensions -notcontains $file.Extension.ToLowerInvariant()) {
            continue
        }
        $relative = $file.FullName.Substring($tierRoot.Length).TrimStart('\', '/')
        $targets += [PSCustomObject]@{
            Id           = $null
            RelativePath = $relative
            Format       = $file.Extension.TrimStart('.').ToUpperInvariant()
            Path         = $file.FullName
        }
    }

    return $targets
}

function Get-FoCorpusSweepWorkDirectoryName {
    param(
        [string]$RelativePath,
        [string]$FullPath
    )

    $label = if ($RelativePath) { $RelativePath } else { [System.IO.Path]::GetFileName($FullPath) }
    Get-FoCorpusSweepSafeLabel -Value $label
}

function Get-FoCorpusSweepSafeLabel {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    ($Value -replace '[\\/:*?"<>|]', '_')
}

function New-FoCorpusSweepResultRow {
    param(
        [string]$Tier,
        $Target,
        $Result,
        [string]$ErrorMessage
    )

    if ($Result) {
        return [PSCustomObject]@{
            Tier             = $Tier
            FixtureId        = $Target.Id
            RelativePath     = $Target.RelativePath
            Format           = $Target.Format
            Status           = $Result.Optimization.Status
            OriginalSize     = $Result.Optimization.OriginalSize
            FinalSize        = $Result.Optimization.FinalSize
            BytesSaved         = $Result.Optimization.BytesSaved
            OptimizeDurationMs = if ($null -ne $Result.OptimizeDurationMs) {
                $Result.OptimizeDurationMs
            }
            else {
                $Result.Optimization.DurationMs
            }
            CompareDurationMs  = $Result.CompareDurationMs
            CompareMode          = $Result.CompareMode
            ComparePass      = if ($Result.Compare) { $Result.Compare.Pass } else { $null }
            MetricValue      = if ($Result.Compare) { $Result.Compare.MetricValue } else { $null }
            Pass             = $Result.Pass
            Error            = if ($Result.CompareError) { $Result.CompareError } else { $null }
            FailureArtifacts = if ($Result.FailureArtifacts) { $Result.FailureArtifacts.Root } else { $null }
            WorkDirectory    = $Result.WorkDirectory
        }
    }

    return [PSCustomObject]@{
        Tier             = $Tier
        FixtureId        = $Target.Id
        RelativePath     = $Target.RelativePath
        Format           = $Target.Format
        Status           = 'Error'
        OriginalSize     = $null
        FinalSize        = $null
        BytesSaved         = $null
        OptimizeDurationMs = $null
        CompareDurationMs  = $null
        CompareMode        = $null
        ComparePass      = $null
        MetricValue      = $null
        Pass             = $false
        Error            = $ErrorMessage
        FailureArtifacts = $null
        WorkDirectory    = $null
    }
}

$targets = @(Get-FoCorpusSweepTargets -TierName $Tier -RootOverride $CorpusRoot)
if ($MaxFiles -gt 0) {
    $targets = @($targets | Select-Object -First $MaxFiles)
}

if ($targets.Count -lt 1) {
    throw "No image files found for Tier $Tier."
}

$sweepRoot = if ($WorkDirectory) {
    [System.IO.Path]::GetFullPath($WorkDirectory)
}
else {
    Join-Path $env:TEMP ("FoCorpusSweep_{0}_{1}" -f $Tier, (Get-Date -Format 'yyyyMMdd_HHmmss'))
}
New-Item -ItemType Directory -Path $sweepRoot -Force | Out-Null

Write-Host ("Corpus sweep: Tier {0}, {1} file(s), profile {2}, compare {3}" -f `
        $Tier, $targets.Count, $ProfileName, $(if ($SkipCompare) { 'skipped' } else { $CompareMode }))
Write-Host "Work directory: $sweepRoot"

$rows = @()
$index = 0
foreach ($target in $targets) {
    $index++
    $label = if ($target.Id) { $target.Id } else { $target.RelativePath }
    Write-Host ("[{0}/{1}] {2}" -f $index, $targets.Count, $label)
    Write-Progress -Activity 'Corpus sweep' -Status $label -PercentComplete (($index / $targets.Count) * 100)

    $itemWorkDir = Join-Path $sweepRoot (Get-FoCorpusSweepWorkDirectoryName -RelativePath $target.RelativePath -FullPath $target.Path)
    New-Item -ItemType Directory -Path $itemWorkDir -Force | Out-Null

    $params = @{
        FixturePath   = $target.Path
        Settings      = $settings
        CompareMode   = $CompareMode
        WorkDirectory = $itemWorkDir
        SkipCompare   = $SkipCompare.IsPresent
    }
    if ($AllowMissingDssim) {
        $params['AllowMissingDssim'] = $true
    }

    if ($CompareMode -eq 'SSIMOnly' -and $ProfileName -eq 'LossyHighQuality') {
        $format = if ($target.Format) { $target.Format } else { 'Default' }
        if ($format -eq 'WEBP') { $format = 'WebP' }
        try {
            $params['SSIMDissimilarityMaximum'] = Get-FoImageTestLossyThreshold -ProfileName $ProfileName -Format $format
        }
        catch {
            $params['SSIMDissimilarityMaximum'] = Get-FoImageTestLossyThreshold -ProfileName $ProfileName -Format 'Default'
        }
    }
    elseif ($CompareMode -eq 'SSIMOnly' -and $target.Format -eq 'AVIF') {
        $params['SSIMDissimilarityMaximum'] = (Get-FoImageTestDecisions).AvifDefaultSSIMDissimilarityMaximum
    }

    try {
        $result = Invoke-FoImageOptimizationTest @params
        if ($result.CompareError) {
            Write-Warning "Compare failed for '$label': $($result.CompareError)"
        }
        $rows += New-FoCorpusSweepResultRow -Tier $Tier -Target $target -Result $result
    }
    catch {
        if (Test-FoCompareDssimRequiredError -Message $_.Exception.Message) {
            throw
        }
        Write-Warning "Sweep error on '$label': $($_.Exception.Message)"
        $rows += New-FoCorpusSweepResultRow -Tier $Tier -Target $target -ErrorMessage $_.Exception.Message
    }
}
Write-Progress -Activity 'Corpus sweep' -Completed

if (-not $OutputCsv) {
    $profileLabel = Get-FoCorpusSweepSafeLabel -Value $ProfileName
    $OutputCsv = Join-Path (Get-Location) ("corpus-sweep-tier{0}-{1}-{2}.csv" -f $Tier.ToLower(), $profileLabel, (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$OutputCsv = [System.IO.Path]::GetFullPath($OutputCsv)
$csvDir = Split-Path -Parent $OutputCsv
if ($csvDir -and -not (Test-Path -LiteralPath $csvDir)) {
    New-Item -ItemType Directory -Path $csvDir -Force | Out-Null
}

$rows | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8

$passed = @($rows | Where-Object { $_.Pass }).Count
$failed = $rows.Count - $passed
$errors = @($rows | Where-Object { $_.Error }).Count
Write-Host ("Done: {0} passed, {1} failed ({2} with errors). CSV: {3}" -f $passed, $failed, $errors, $OutputCsv)
Write-Host "Failure artifact roots under: $sweepRoot"

if ($failed -gt 0) {
    exit 1
}

exit 0
