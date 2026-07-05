# DSSIM compare tool metadata — upstream GitHub release (not ps-file-optimizer-aux).

$script:FoDssimVersion = '3.4.0'
$script:FoDssimBundleUrl = 'https://github.com/kornelski/dssim/releases/download/3.4.0/dssim-3.4.0.zip'
$script:FoDssimBundleFileName = 'dssim-3.4.0.zip'
$script:FoDssimBundleSha256 = 'c9cb7089a62fd8c2655e778fc576d9f1f453eb3ecfb98bb6914f1ff086ceda4c'
$script:FoDssimWindowsRelativePath = 'win\dssim.exe'
$script:FoDssimInstallRelativePath = 'dssim\dssim.exe'

function Get-FoDssimBundleSettings {
    [CmdletBinding()]
    param(
        [string]$ArchiveUrl,
        [string]$ArchiveSha256
    )

    if ($env:FO_DSSIM_BUNDLE_URL) {
        $fileName = if ($env:FO_DSSIM_BUNDLE_FILENAME) {
            $env:FO_DSSIM_BUNDLE_FILENAME
        }
        else {
            [System.IO.Path]::GetFileName(($env:FO_DSSIM_BUNDLE_URL -split '\?')[0])
        }

        return [PSCustomObject]@{
            Version  = $script:FoDssimVersion
            Url      = $env:FO_DSSIM_BUNDLE_URL
            FileName = $fileName
            Sha256   = if ($env:FO_DSSIM_BUNDLE_SHA256) { $env:FO_DSSIM_BUNDLE_SHA256 } else { $ArchiveSha256 }
        }
    }

    if ($ArchiveUrl) {
        return [PSCustomObject]@{
            Version  = $script:FoDssimVersion
            Url      = $ArchiveUrl
            FileName = [System.IO.Path]::GetFileName(($ArchiveUrl -split '\?')[0])
            Sha256   = $ArchiveSha256
        }
    }

    return [PSCustomObject]@{
        Version  = $script:FoDssimVersion
        Url      = $script:FoDssimBundleUrl
        FileName = $script:FoDssimBundleFileName
        Sha256   = $script:FoDssimBundleSha256
    }
}

function Get-FoDssimInstallPath {
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
        else {
            $searchPath = Join-Path $script:FoModuleRoot 'plugins'
        }
    }

    return Join-Path ([System.IO.Path]::GetFullPath($searchPath)) ($script:FoDssimInstallRelativePath -replace '\\', [System.IO.Path]::DirectorySeparatorChar)
}

function Test-FoDssimCompareAvailable {
    [CmdletBinding()]
    param(
        [string]$PluginPath
    )

    if (-not [Environment]::Is64BitProcess) {
        return $false
    }

    $path = Get-FoDssimInstallPath -PluginPath $PluginPath
    return (Test-Path -LiteralPath $path)
}

function Resolve-FoDssimExecutable {
    [CmdletBinding()]
    param(
        [string]$PluginPath
    )

    $path = Get-FoDssimInstallPath -PluginPath $PluginPath
    return [PSCustomObject]@{
        Name   = 'dssim.exe'
        Path   = if (Test-Path -LiteralPath $path) { $path } else { $null }
        Source = 'Portable'
        Found  = (Test-Path -LiteralPath $path)
    }
}
