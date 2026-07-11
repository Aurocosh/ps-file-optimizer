#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ModuleRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory,
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'

function Get-FoShipRootNames {
    return @(
        'FileOptimizer.psd1'
        'FileOptimizer.psm1'
        'Public'
        'Private'
        'Pipelines'
        'Scripts'
        'Data'
        'Templates'
        'README.md'
    )
}

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $ModuleRoot 'FileOptimizer.psd1'
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Module manifest not found: $ManifestPath"
}

$manifestContent = Get-Content -LiteralPath $ManifestPath -Raw
$manifest = & ([scriptblock]::Create($manifestContent))
$version = [version]$manifest.ModuleVersion

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $ModuleRoot 'dist'
}

$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("fo-release-{0}" -f [guid]::NewGuid().ToString('N'))
$moduleFolder = Join-Path (Join-Path $stagingRoot 'FileOptimizer') $version.ToString()

try {
    New-Item -ItemType Directory -Path $moduleFolder -Force | Out-Null

    foreach ($name in (Get-FoShipRootNames)) {
        $source = Join-Path $ModuleRoot $name
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Required release path missing: $source"
        }

        $destination = Join-Path $moduleFolder $name
        if (Test-Path -LiteralPath $source -PathType Container) {
            Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
        }
        else {
            Copy-Item -LiteralPath $source -Destination $destination -Force
        }
    }

    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $zipName = 'FileOptimizer-{0}.zip' -f $version
    $zipPath = Join-Path $OutputDirectory $zipName
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    $archiveSource = Join-Path $stagingRoot 'FileOptimizer'
    Compress-Archive -LiteralPath $archiveSource -DestinationPath $zipPath -Force

    [PSCustomObject]@{
        Version     = $version
        ArchivePath = (Resolve-Path -LiteralPath $zipPath).Path
        ModuleRoot  = $ModuleRoot
    }
}
finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
