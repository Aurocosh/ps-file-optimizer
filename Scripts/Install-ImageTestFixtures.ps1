[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$UpstreamPath,
    [string]$Destination,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$moduleRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $moduleRoot 'Tests\ImageTestManifest.psd1'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest not found: $manifestPath"
}

. (Join-Path $moduleRoot 'Private\Import-FoDataFile.ps1')
$manifest = Import-FoDataFile -Path $manifestPath

$upstreamRoot = [System.IO.Path]::GetFullPath($UpstreamPath)
if (-not (Test-Path -LiteralPath $upstreamRoot)) {
    throw "Upstream path not found: $upstreamRoot"
}

$destRoot = if ($Destination) {
    [System.IO.Path]::GetFullPath($Destination)
}
else {
    Join-Path $moduleRoot 'Tests\Fixtures\Images'
}

$files = @($manifest.Tiers.A.Files)
if ($files.Count -eq 0) {
    throw 'No Tier A files listed in ImageTestManifest.psd1.'
}

Write-Host ("Installing {0} Tier A fixtures to {1}" -f $files.Count, $destRoot)

$hashLines = @()
$copied = 0
$totalBytes = 0

foreach ($entry in $files) {
    $relative = $entry.Source -replace '/', [System.IO.Path]::DirectorySeparatorChar
    $sourcePath = Join-Path $upstreamRoot $relative
    $targetPath = Join-Path $destRoot $relative

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Missing upstream file: $sourcePath"
    }

    $targetDir = Split-Path -Parent $targetPath
    if (-not $WhatIf -and $targetDir -and -not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    if ($WhatIf) {
        Write-Host "WHATIF: $($entry.Source)"
        continue
    }

    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    $hash = Get-FileHash -LiteralPath $targetPath -Algorithm SHA256
    $hashLines += ("{0}  {1}" -f $hash.Hash.ToLowerInvariant(), ($entry.Source -replace '\\', '/'))
    $copied++
    $totalBytes += (Get-Item -LiteralPath $targetPath).Length
}

if (-not $WhatIf) {
    $manifestFile = Join-Path $destRoot 'MANIFEST.sha256'
    $header = @(
        "# FO-ImageTest-v1 Tier A"
        "# Upstream: $($manifest.UpstreamRepo) @ $($manifest.UpstreamCommit)"
        ""
    )
    Set-Content -LiteralPath $manifestFile -Value ($header + $hashLines) -Encoding UTF8
    Write-Host ("Copied {0} files ({1} bytes). Wrote {2}" -f $copied, $totalBytes, $manifestFile)
}
