function Install-FoDssimBundleCore {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$DestinationPath,
        [string]$ArchiveUrl,
        [string]$ArchiveSha256,
        [string]$TempDirectory,
        [switch]$Force,
        [bool]$ShowProgress = $true
    )

    $pluginRoot = if ($DestinationPath) {
        [System.IO.Path]::GetFullPath($DestinationPath)
    }
    else {
        Get-FoDefaultPluginPath
    }

    $destExe = Join-Path $pluginRoot ($script:FoDssimInstallRelativePath -replace '\\', [System.IO.Path]::DirectorySeparatorChar)
    $destDir = Split-Path -Parent $destExe

    if (-not [Environment]::Is64BitProcess) {
        return [PSCustomObject]@{
            Component       = 'Dssim'
            DestinationPath = $pluginRoot
            InstalledPath   = $destExe
            Downloaded      = $false
            Extracted       = $false
            Skipped         = $true
            Message         = 'DSSIM is 64-bit only; skipped on 32-bit PowerShell.'
        }
    }

    if ((Test-Path -LiteralPath $destExe) -and -not $Force) {
        return [PSCustomObject]@{
            Component       = 'Dssim'
            DestinationPath   = $pluginRoot
            InstalledPath     = $destExe
            Version           = $script:FoDssimVersion
            Downloaded        = $false
            Extracted         = $false
            Skipped           = $true
            Message           = "DSSIM already present at $destExe."
        }
    }

    $bundle = Get-FoDssimBundleSettings -ArchiveUrl $ArchiveUrl -ArchiveSha256 $ArchiveSha256
    $tempRoot = if ($TempDirectory) {
        [System.IO.Path]::GetFullPath($TempDirectory)
    }
    else {
        Join-Path ([System.IO.Path]::GetTempPath()) "FoDssimInstall_$(Get-Random)"
    }

    $archivePath = Join-Path $tempRoot $bundle.FileName
    $extractRoot = Join-Path $tempRoot 'extract'

    try {
        if (-not (Test-Path -LiteralPath $tempRoot)) {
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        }

        if ($PSCmdlet.ShouldProcess($bundle.Url, 'Download DSSIM bundle')) {
            Invoke-FoPluginBundleDownload -DestinationFile $archivePath -Url $bundle.Url -ShowProgress:$ShowProgress
            Test-FoDownloadedFileSha256 -Path $archivePath -ExpectedSha256 $bundle.Sha256
        }
        else {
            return [PSCustomObject]@{
                Component       = 'Dssim'
                DestinationPath = $pluginRoot
                InstalledPath   = $destExe
                Version         = $bundle.Version
                Downloaded      = $false
                Extracted       = $false
                Skipped         = $false
                Message         = 'WhatIf: would download DSSIM bundle and install win/dssim.exe.'
            }
        }

        if ($PSCmdlet.ShouldProcess($archivePath, 'Extract DSSIM zip')) {
            if (Test-Path -LiteralPath $extractRoot) {
                Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
            Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force
        }

        $sourceExe = Join-Path $extractRoot ($script:FoDssimWindowsRelativePath -replace '\\', [System.IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $sourceExe)) {
            throw "DSSIM archive did not contain expected path '$($script:FoDssimWindowsRelativePath)'."
        }

        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        if ($PSCmdlet.ShouldProcess($destExe, 'Install DSSIM executable')) {
            Copy-Item -LiteralPath $sourceExe -Destination $destExe -Force
        }

        return [PSCustomObject]@{
            Component       = 'Dssim'
            DestinationPath = $pluginRoot
            InstalledPath   = $destExe
            Version         = $bundle.Version
            ArchiveUrl      = $bundle.Url
            Downloaded      = $true
            Extracted       = $true
            Skipped         = $false
            Message         = "Installed DSSIM $($bundle.Version) to $destExe."
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
