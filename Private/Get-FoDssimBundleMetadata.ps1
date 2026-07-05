# DSSIM compare tool metadata — upstream GitHub release (not ps-file-optimizer-aux).

$script:FoDssimVersion = '3.4.0'
$script:FoDssimBundleUrl = 'https://github.com/kornelski/dssim/releases/download/3.4.0/dssim-3.4.0.zip'
$script:FoDssimBundleFileName = 'dssim-3.4.0.zip'
$script:FoDssimBundleSha256 = 'c9cb7089a62fd8c2655e778fc576d9f1f453eb3ecfb98bb6914f1ff086ceda4c'
$script:FoDssimWindowsRelativePath = 'win\dssim.exe'
$script:FoDssimInstallRelativePath = 'dssim\dssim.exe'
$script:FoCompareDssimRequiredPrefix = 'DSSIM is required for PNG pixel compare'

function Test-FoCompareAllowMissingDssim {
    [CmdletBinding()]
    param(
        [switch]$AllowMissingDssim
    )

    if ($AllowMissingDssim) {
        return $true
    }

    $envVal = $env:FO_COMPARE_ALLOW_MISSING_DSSIM
    if ($envVal -and ($envVal -match '^(1|true|yes)$')) {
        return $true
    }

    return $false
}

function Test-FoCompareDssimRequiredError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    return ($Message -like "$($script:FoCompareDssimRequiredPrefix)*")
}

function Get-FoDssimCompareRequiredMessage {
    [CmdletBinding()]
    param(
        [string]$PluginPath
    )

    $expectedPath = Get-FoDssimInstallPath -PluginPath $PluginPath
    $hint = if (-not [Environment]::Is64BitProcess) {
        'DSSIM requires 64-bit PowerShell. Pass -AllowMissingDssim or set FO_COMPARE_ALLOW_MISSING_DSSIM=1 to fall back to ImageMagick AE.'
    }
    else {
        'Run Scripts/Install-Dssim.ps1 (or Install-FoDssim). Pass -AllowMissingDssim or set FO_COMPARE_ALLOW_MISSING_DSSIM=1 to fall back to ImageMagick AE.'
    }

    return "$($script:FoCompareDssimRequiredPrefix) but dssim.exe was not found at '$expectedPath'. $hint"
}

function Assert-FoDssimCompareAvailable {
    [CmdletBinding()]
    param(
        [string]$PluginPath,
        [switch]$AllowMissingDssim
    )

    if (Test-FoCompareAllowMissingDssim -AllowMissingDssim:$AllowMissingDssim) {
        return
    }

    if (Test-FoDssimCompareAvailable -PluginPath $PluginPath) {
        return
    }

    throw (Get-FoDssimCompareRequiredMessage -PluginPath $PluginPath)
}

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
        if (-not $searchPath -and (Get-Command Get-FoDefaultPluginPath -ErrorAction SilentlyContinue)) {
            $searchPath = Get-FoDefaultPluginPath
        }
        if (-not $searchPath -and $script:FoModuleRoot) {
            $prefer64 = [Environment]::Is64BitProcess
            foreach ($name in $(if ($prefer64) { @('Plugins64', 'Plugins32') } else { @('Plugins32', 'Plugins64') })) {
                $candidate = Join-Path $script:FoModuleRoot $name
                if (Test-Path -LiteralPath $candidate) {
                    $searchPath = $candidate
                    break
                }
            }
        }
    }

    if (-not $searchPath) {
        return $null
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
    if (-not $path) {
        return $false
    }
    return (Test-Path -LiteralPath $path)
}

function Resolve-FoDssimExecutable {
    [CmdletBinding()]
    param(
        [string]$PluginPath
    )

    $path = Get-FoDssimInstallPath -PluginPath $PluginPath
    $found = $path -and (Test-Path -LiteralPath $path)
    return [PSCustomObject]@{
        Name   = 'dssim.exe'
        Path   = if ($found) { $path } else { $null }
        Source = 'Portable'
        Found  = $found
    }
}
