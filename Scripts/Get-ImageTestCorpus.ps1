#Requires -Version 5.1
<#
.SYNOPSIS
  Download or verify FO-ImageTest-v1 corpus tiers.

.PARAMETER Tier
  A — verify committed Tier A fixtures against MANIFEST.sha256.
  B, C, D — download tier zip from ps-file-optimizer-aux release and extract.

.PARAMETER Destination
  Corpus root. Default: FO_TEST_CORPUS_PATH or Tests/Fixtures/Corpus under module root.

.PARAMETER Force
  Re-download and replace an existing tier archive extract.

.EXAMPLE
  .\Scripts\Get-ImageTestCorpus.ps1 -Tier A
  .\Scripts\Get-ImageTestCorpus.ps1 -Tier B
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('A', 'B', 'C', 'D')]
    [string]$Tier,
    [string]$Destination,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force
Import-Module (Join-Path $moduleRoot 'Tests\FoTestSupport\FoTestSupport.psd1') -Force

$manifest = Import-FoDataFile -Path (Join-Path $moduleRoot 'Tests\ImageTestManifest.psd1')

function Expand-FoZipArchive {
    param(
        [Parameter(Mandatory)]
        [string]$ArchivePath,
        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }

    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $DestinationPath -Force
}

function Test-FoImageTestTierAManifest {
    $fixtureRoot = Join-Path $moduleRoot 'Tests\Fixtures\Images'
    $manifestFile = Join-Path $fixtureRoot 'MANIFEST.sha256'
    if (-not (Test-Path -LiteralPath $manifestFile)) {
        throw "Tier A manifest not found: $manifestFile"
    }

    $lines = Get-Content -LiteralPath $manifestFile | Where-Object {
        $_ -and $_ -notmatch '^\s*#'
    }

    $failures = @()
    foreach ($line in $lines) {
        if ($line -notmatch '^([a-f0-9]{64})\s+(.+)$') {
            continue
        }
        $expected = $Matches[1]
        $relative = $Matches[2]
        $path = Join-Path $fixtureRoot ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $path)) {
            $failures += "Missing file: $relative"
            continue
        }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) {
            $failures += "Hash mismatch: $relative"
        }
    }

    $presence = Test-FoImageTestFixturesPresent -Tier A
    if (-not $presence.Present) {
        $failures += "Missing Tier A fixtures: $($presence.Missing -join ', ')"
    }

    return [PSCustomObject]@{
        Tier      = 'A'
        Verified  = ($failures.Count -eq 0)
        Failures  = @($failures)
        FileCount = $presence.Count
        Root      = $fixtureRoot
    }
}

$corpusRoot = Get-FoImageTestCorpusRoot -Override $Destination

if ($Tier -eq 'A') {
    $result = Test-FoImageTestTierAManifest
    if (-not $result.Verified) {
        throw ("Tier A verification failed:`n" + ($result.Failures -join "`n"))
    }
    Write-Host "Tier A verified: $($result.FileCount) fixtures under $($result.Root)"
    return $result
}

if (-not $manifest.AuxReleases) {
    throw 'ImageTestManifest.psd1 has no AuxReleases block.'
}

$release = $manifest.AuxReleases[$Tier]
if (-not $release) {
    throw "No AuxReleases entry for Tier $Tier."
}

$asset = $release.Asset
$tag = if ($manifest.AuxReleaseTag) {
    $manifest.AuxReleaseTag
}
elseif ($release.Tag) {
    $release.Tag
}
else {
    throw "No AuxReleaseTag in manifest and no Tag on Tier $Tier release entry."
}
$url = if ($release.Url) {
    $release.Url
}
else {
    $base = if ($manifest.AuxBaseUrl) { $manifest.AuxBaseUrl } else { 'https://github.com/Aurocosh/ps-file-optimizer-aux/releases/download' }
    "$base/$tag/$asset"
}

$tierDir = Join-Path $corpusRoot ("tier-$($Tier.ToLower())")
$archivePath = Join-Path $corpusRoot $asset

if ((Test-Path -LiteralPath $tierDir) -and -not $Force) {
    $existing = @(Get-ChildItem -LiteralPath $tierDir -Recurse -File -ErrorAction SilentlyContinue).Count
    if ($existing -gt 0) {
        Write-Host "Tier $Tier already present at $tierDir ($existing files). Use -Force to re-download."
        return [PSCustomObject]@{
            Tier        = $Tier
            Downloaded  = $false
            Extracted   = $false
            Destination = $tierDir
            FileCount   = $existing
            Url         = $url
        }
    }
}

if (-not (Test-Path -LiteralPath $corpusRoot)) {
    New-Item -ItemType Directory -Path $corpusRoot -Force | Out-Null
}

if ($PSCmdlet.ShouldProcess($url, "Download image test Tier $Tier")) {
    Invoke-FoPluginBundleDownload -DestinationFile $archivePath -Url $url -ShowProgress:$true
    if ($release.Sha256) {
        Test-FoDownloadedFileSha256 -Path $archivePath -ExpectedSha256 $release.Sha256
    }
    else {
        Write-Warning "No Sha256 pinned for Tier $Tier in ImageTestManifest.psd1; skipping integrity check."
    }

    if (Test-Path -LiteralPath $tierDir) {
        Remove-Item -LiteralPath $tierDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tierDir -Force | Out-Null
    Expand-FoZipArchive -ArchivePath $archivePath -DestinationPath $tierDir

    $fileCount = @(Get-ChildItem -LiteralPath $tierDir -Recurse -File).Count
    Write-Host "Tier $Tier extracted to $tierDir ($fileCount files)."

    return [PSCustomObject]@{
        Tier        = $Tier
        Downloaded  = $true
        Extracted   = $true
        Destination = $tierDir
        FileCount   = $fileCount
        Url         = $url
        ArchivePath = $archivePath
    }
}

Write-Host "WhatIf: would download $url and extract to $tierDir"
