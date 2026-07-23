#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ModuleRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ManifestPath,
    [string]$NuGetApiKey = $env:PSGALLERY_API_KEY,
    [string]$Repository = 'PSGallery',
    [string]$ModulePath
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

function Get-FoManifestPrereleaseLabel {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $content = Get-Content -LiteralPath $Path -Raw
    $manifest = & ([scriptblock]::Create($content))
    return [string]$manifest.PrivateData.PSData.Prerelease
}

function Get-FoLatestGalleryModuleVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$RepositoryName,
        [string]$PrereleaseLabel
    )

    $findParams = @{
        Name        = $Name
        Repository  = $RepositoryName
        ErrorAction = 'SilentlyContinue'
    }

    if ($PrereleaseLabel) {
        $findParams['AllowPrerelease'] = $true
    }

    $found = Find-Module @findParams | Sort-Object { [version]$_.Version } -Descending | Select-Object -First 1
    if (-not $found) {
        return $null
    }

    return [version]$found.Version
}

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $ModuleRoot 'FileOptimizer.psd1'
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Module manifest not found: $ManifestPath"
}

if ([string]::IsNullOrWhiteSpace($NuGetApiKey)) {
    Write-Host 'PSGALLERY_API_KEY is not set; skipping PowerShell Gallery publish.'
    exit 0
}

$moduleVersion = Get-FoModuleVersionFromManifest -Path $ManifestPath
$prereleaseLabel = Get-FoManifestPrereleaseLabel -Path $ManifestPath
$latestGalleryVersion = Get-FoLatestGalleryModuleVersion -Name 'FileOptimizer' -RepositoryName $Repository -PrereleaseLabel $prereleaseLabel

Write-Host "ModuleVersion: $moduleVersion"
Write-Host "Latest $Repository version: $(if ($latestGalleryVersion) { $latestGalleryVersion } else { '<none>' })"

if ($latestGalleryVersion -and $moduleVersion -eq $latestGalleryVersion) {
    Write-Host "ModuleVersion matches the latest $Repository release; no Gallery publish required."
    exit 0
}

if ($latestGalleryVersion -and $moduleVersion -lt $latestGalleryVersion) {
    Write-Warning "ModuleVersion $moduleVersion is older than the latest $Repository version $latestGalleryVersion; skipping."
    exit 0
}

$resolveNotes = Join-Path $PSScriptRoot 'Resolve-FoReleaseNotesFile.ps1'
$notesFile = & $resolveNotes -ModuleRoot $ModuleRoot -Version $moduleVersion
if (-not $notesFile) {
    throw ("ModuleVersion {0} is newer than the latest {1} release, but ReleaseNotes/{0}.md is missing. Add release notes before publishing." -f $moduleVersion, $Repository)
}

if (-not $ModulePath) {
    $buildScript = Join-Path $PSScriptRoot 'Build-FoModuleRelease.ps1'
    $build = & $buildScript -ModuleRoot $ModuleRoot -ManifestPath $ManifestPath
    $ModulePath = $build.ModulePath
}

if (-not (Test-Path -LiteralPath $ModulePath)) {
    throw "Packaged module path not found: $ModulePath"
}

$publishRoot = Split-Path -Parent $ModulePath
Write-Host "Publishing FileOptimizer $moduleVersion to $Repository from $publishRoot using $($notesFile.Path)"

if (-not $PSCmdlet.ShouldProcess($Repository, "Publish-Module FileOptimizer $moduleVersion")) {
    exit 0
}

$publishParams = @{
    Path            = $publishRoot
    NuGetApiKey     = $NuGetApiKey
    Repository      = $Repository
    RequiredVersion = $moduleVersion.ToString()
    ReleaseNotes    = @($notesFile.Content)
    Force           = $true
    ErrorAction     = 'Stop'
}

if ($prereleaseLabel) {
    $publishParams['AllowPrerelease'] = $true
}

Publish-Module @publishParams
Write-Host "Published FileOptimizer $moduleVersion to $Repository."
