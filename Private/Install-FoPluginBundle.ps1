function Invoke-FoPluginBundleDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DestinationFile,
        [Parameter(Mandatory)]
        [string]$Url
    )

    $destDir = Split-Path -Parent $DestinationFile
    if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $partFile = "$DestinationFile.part"
    if (Test-Path -LiteralPath $partFile) {
        Remove-Item -LiteralPath $partFile -Force -ErrorAction SilentlyContinue
    }

    Write-Verbose "Downloading FileOptimizer bundle from $Url"
    try {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            Invoke-WebRequest -Uri $Url -OutFile $partFile -UseBasicParsing -ErrorAction Stop
        }
        else {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add('User-Agent', 'PS-FileOptimizer/1.0')
            $webClient.DownloadFile($Url, $partFile)
            $webClient.Dispose()
        }
    }
    catch {
        if (Test-Path -LiteralPath $partFile) {
            Remove-Item -LiteralPath $partFile -Force -ErrorAction SilentlyContinue
        }
        throw "Failed to download FileOptimizer bundle from '$Url'. $($_.Exception.Message)"
    }

    Move-Item -LiteralPath $partFile -Destination $DestinationFile -Force
}

function Copy-FoPluginFilesFromBundle {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePluginDir,
        [Parameter(Mandatory)]
        [string]$DestinationPluginDir,
        [Parameter(Mandatory)]
        [string[]]$FileNames,
        [switch]$Force
    )

    if (-not (Test-Path -LiteralPath $DestinationPluginDir)) {
        New-Item -ItemType Directory -Path $DestinationPluginDir -Force | Out-Null
    }

    $copied = [System.Collections.Generic.List[string]]::new()
    $skipped = [System.Collections.Generic.List[string]]::new()
    $missing = [System.Collections.Generic.List[string]]::new()

    foreach ($name in $FileNames) {
        $src = Get-ChildItem -LiteralPath $SourcePluginDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ieq $name } |
            Select-Object -First 1

        if (-not $src) {
            $missing.Add($name)
            continue
        }

        $destPath = Join-Path $DestinationPluginDir $src.Name
        if ((Test-Path -LiteralPath $destPath) -and -not $Force) {
            $skipped.Add($src.Name)
            continue
        }

        $target = $destPath
        if ($PSCmdlet.ShouldProcess($target, 'Copy plugin file from FileOptimizer bundle')) {
            Copy-Item -LiteralPath $src.FullName -Destination $target -Force
            $copied.Add($src.Name)
        }
    }

    return [PSCustomObject]@{
        Copied  = @($copied)
        Skipped = @($skipped)
        Missing = @($missing)
    }
}

function Install-FoPluginBundleCore {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('FullPortable', 'Missing')]
        [string]$Mode = 'FullPortable',
        [string]$DestinationPath,
        [string]$ArchiveUrl,
        [string]$TempDirectory,
        [switch]$Force
    )

    $dest = if ($DestinationPath) {
        [System.IO.Path]::GetFullPath($DestinationPath)
    }
    else {
        Join-Path $script:FoModuleRoot 'plugins'
    }

    $url = if ($ArchiveUrl) { $ArchiveUrl } else { $script:FoPluginBundleUrl }
    $requiredExes = Get-FoRequiredPluginExecutables

    $exesToInstall = switch ($Mode) {
        'FullPortable' { $requiredExes }
        'Missing' {
            Get-FoMissingPluginExecutables -PluginPath $dest -RequiredExecutables $requiredExes
        }
    }

    if ($Mode -eq 'Missing' -and $exesToInstall.Count -eq 0) {
        return [PSCustomObject]@{
            Mode              = $Mode
            DestinationPath   = $dest
            Downloaded        = $false
            Extracted         = $false
            ExecutablesNeeded = @()
            FilesCopied       = @()
            FilesSkipped      = @()
            FilesMissing      = @()
            Message           = 'All required plugin executables are already present.'
        }
    }

    $tempRoot = if ($TempDirectory) {
        [System.IO.Path]::GetFullPath($TempDirectory)
    }
    else {
        Join-Path ([System.IO.Path]::GetTempPath()) "FoPluginInstall_$(Get-Random)"
    }

    $archivePath = Join-Path $tempRoot $script:FoPluginBundleFileName
    $extractRoot = Join-Path $tempRoot 'extract'
    $bootstrapDir = Join-Path $tempRoot '7z-bootstrap'

    $downloaded = $false
    $extracted = $false
    $copyResult = $null
    $sevenZipBootstrap = $null

    try {
        if (-not (Test-Path -LiteralPath $tempRoot)) {
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        }

        if ($PSCmdlet.ShouldProcess($url, 'Download FileOptimizer plugin bundle')) {
            Invoke-FoPluginBundleDownload -DestinationFile $archivePath -Url $url
            $downloaded = $true
        }
        else {
            return [PSCustomObject]@{
                Mode              = $Mode
                DestinationPath   = $dest
                Downloaded        = $false
                Extracted         = $false
                ExecutablesNeeded = $exesToInstall
                FilesCopied       = @()
                FilesSkipped      = @()
                FilesMissing      = @()
                Message           = 'WhatIf: would download bundle and copy plugin files.'
            }
        }

        if ($PSCmdlet.ShouldProcess($archivePath, 'Extract FileOptimizer bundle with 7-Zip (without running SFX)')) {
            $expand = Expand-Fo7zArchive -ArchivePath $archivePath -DestinationPath $extractRoot -PassThru
            $sevenZipBootstrap = $expand.BootstrapDir
            $extracted = $true
        }

        $sourcePlugins = Resolve-FoBundledPluginDirectory -ExtractRoot $extractRoot
        $filesToCopy = Get-FoPluginInstallFilePlan -Executables $exesToInstall -SourcePluginDir $sourcePlugins

        $copyResult = Copy-FoPluginFilesFromBundle `
            -SourcePluginDir $sourcePlugins `
            -DestinationPluginDir $dest `
            -FileNames $filesToCopy `
            -Force:$Force

        return [PSCustomObject]@{
            Mode              = $Mode
            DestinationPath   = $dest
            ArchiveUrl        = $url
            Downloaded        = $downloaded
            Extracted         = $extracted
            ExecutablesNeeded = $exesToInstall
            FilesPlanned      = $filesToCopy
            FilesCopied       = $copyResult.Copied
            FilesSkipped      = $copyResult.Skipped
            FilesMissing      = $copyResult.Missing
            Message           = if ($copyResult.Missing.Count) {
                "Copied $($copyResult.Copied.Count) file(s); $($copyResult.Missing.Count) not found in bundle."
            }
            else {
                "Copied $($copyResult.Copied.Count) file(s) to $dest."
            }
        }
    }
    finally {
        if ($sevenZipBootstrap -and (Test-Path -LiteralPath $sevenZipBootstrap)) {
            Remove-Item -LiteralPath $sevenZipBootstrap -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
