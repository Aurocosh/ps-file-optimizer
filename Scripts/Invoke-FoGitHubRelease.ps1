#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$ModuleRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ManifestPath,
    [string]$MinimumReleaseVersion = '1.0.0',
    [string]$ReleaseNotes,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Get-FoModuleVersionFromManifest {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $content = Get-Content -LiteralPath $Path -Raw
    $manifest = & ([scriptblock]::Create($content))
    if (-not $manifest.ModuleVersion) {
        throw "Module manifest '$Path' is missing ModuleVersion."
    }

    return [version]$manifest.ModuleVersion
}

function Get-FoLatestGitHubReleaseVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Repo
    )

    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw 'GitHub CLI (gh) is required but was not found on PATH.'
    }

    $output = gh release list --repo $Repo --limit 1 --json tagName --jq '.[0].tagName' 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to query GitHub releases for '$Repo'. Ensure GH_TOKEN is set and the token can read releases."
    }

    if ([string]::IsNullOrWhiteSpace($output)) {
        return $null
    }

    return [version]($output.Trim() -replace '^[vV]', '')
}

function Get-FoDefaultReleaseNotes {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [version]$Version
    )

    $content = Get-Content -LiteralPath $Path -Raw
    $manifest = & ([scriptblock]::Create($content))
    $notes = $manifest.PrivateData.PSData.ReleaseNotes
    if ($notes) {
        return $notes
    }

    return "PS-FileOptimizer $Version"
}

if (-not $Repository) {
    throw 'Repository is required. Set -Repository or GITHUB_REPOSITORY.'
}

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $ModuleRoot 'FileOptimizer.psd1'
}

$moduleVersion = Get-FoModuleVersionFromManifest -Path $ManifestPath
$minimumVersion = [version]$MinimumReleaseVersion
$latestReleaseVersion = Get-FoLatestGitHubReleaseVersion -Repo $Repository

Write-Host "ModuleVersion: $moduleVersion"
Write-Host "Minimum release version: $minimumVersion"
Write-Host "Latest GitHub release: $(if ($latestReleaseVersion) { $latestReleaseVersion } else { '<none>' })"

if ($moduleVersion -lt $minimumVersion) {
    Write-Host "ModuleVersion $moduleVersion is below minimum release version $minimumVersion; skipping GitHub release."
    exit 0
}

if ($latestReleaseVersion -and $moduleVersion -eq $latestReleaseVersion) {
    Write-Host 'ModuleVersion matches the latest GitHub release; no new release required.'
    exit 0
}

if ($latestReleaseVersion -and $moduleVersion -lt $latestReleaseVersion) {
    Write-Warning "ModuleVersion $moduleVersion is older than the latest GitHub release $latestReleaseVersion; skipping."
    exit 0
}

if (-not $ReleaseNotes) {
    $ReleaseNotes = Get-FoDefaultReleaseNotes -Path $ManifestPath -Version $moduleVersion
}

$buildScript = Join-Path $PSScriptRoot 'Build-FoModuleRelease.ps1'
$build = & $buildScript -ModuleRoot $ModuleRoot -ManifestPath $ManifestPath
$tagName = 'v{0}' -f $moduleVersion
$title = $tagName

Write-Host "Publishing GitHub release $tagName from $($build.ArchivePath)"

if ($WhatIf) {
    Write-Host 'WhatIf: release would be created.'
    exit 0
}

if (-not $PSCmdlet.ShouldProcess($Repository, "Create GitHub release $tagName")) {
    exit 0
}

$ghArgs = @(
    'release', 'create', $tagName, $build.ArchivePath
    '--repo', $Repository
    '--title', $title
    '--notes', $ReleaseNotes
)

& gh @ghArgs
if ($LASTEXITCODE -ne 0) {
    throw "gh release create failed with exit code $LASTEXITCODE."
}

Write-Host "Created GitHub release $tagName."
