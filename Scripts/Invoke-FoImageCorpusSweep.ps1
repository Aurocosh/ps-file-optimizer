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
  CSV path for results. Default: ./corpus-sweep-{tier}-{timestamp}.csv under current directory.

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
    Write-Progress -Activity 'Corpus sweep' -Status $label -PercentComplete (($index / $targets.Count) * 100)

    $itemWorkDir = Join-Path $sweepRoot ([System.IO.Path]::GetFileNameWithoutExtension($target.Path))
    New-Item -ItemType Directory -Path $itemWorkDir -Force | Out-Null

    $params = @{
        FixturePath   = $target.Path
        Settings      = $settings
        CompareMode   = $CompareMode
        WorkDirectory = $itemWorkDir
        SkipCompare   = $SkipCompare.IsPresent
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

    $result = Invoke-FoImageOptimizationTest @params

    $rows += [PSCustomObject]@{
        Tier              = $Tier
        FixtureId         = $target.Id
        RelativePath      = $target.RelativePath
        Format            = $target.Format
        Status            = $result.Optimization.Status
        OriginalSize      = $result.Optimization.OriginalSize
        FinalSize         = $result.Optimization.FinalSize
        BytesSaved        = $result.Optimization.BytesSaved
        DurationMs        = $result.Optimization.DurationMs
        CompareMode       = $result.CompareMode
        ComparePass       = if ($result.Compare) { $result.Compare.Pass } else { $null }
        MetricValue       = if ($result.Compare) { $result.Compare.MetricValue } else { $null }
        Pass              = $result.Pass
        FailureArtifacts  = if ($result.FailureArtifacts) { $result.FailureArtifacts.Root } else { $null }
        WorkDirectory     = $result.WorkDirectory
    }
}
Write-Progress -Activity 'Corpus sweep' -Completed

if (-not $OutputCsv) {
    $OutputCsv = Join-Path (Get-Location) ("corpus-sweep-tier{0}-{1}.csv" -f $Tier.ToLower(), (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$OutputCsv = [System.IO.Path]::GetFullPath($OutputCsv)
$csvDir = Split-Path -Parent $OutputCsv
if ($csvDir -and -not (Test-Path -LiteralPath $csvDir)) {
    New-Item -ItemType Directory -Path $csvDir -Force | Out-Null
}

$rows | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8

$passed = @($rows | Where-Object { $_.Pass }).Count
$failed = $rows.Count - $passed
Write-Host ("Done: {0} passed, {1} failed. CSV: {2}" -f $passed, $failed, $OutputCsv)
Write-Host "Failure artifact roots under: $sweepRoot"

if ($failed -gt 0) {
    exit 1
}

exit 0
