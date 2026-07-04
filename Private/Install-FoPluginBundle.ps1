function Invoke-FoPluginBundleDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DestinationFile,
        [Parameter(Mandatory)]
        [string]$Url,
        [bool]$ShowProgress = $true
    )

    $destDir = Split-Path -Parent $DestinationFile
    if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $partFile = "$DestinationFile.part"
    if (Test-Path -LiteralPath $partFile) {
        Remove-Item -LiteralPath $partFile -Force -ErrorAction SilentlyContinue
    }

    $activity = 'Downloading FileOptimizer bundle'
    $fileName = Split-Path -Leaf $DestinationFile

    Write-Verbose "Downloading FileOptimizer bundle from $Url"
    if ($ShowProgress) {
        Write-Host "Downloading $fileName ..."
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.UserAgent = 'PS-FileOptimizer/1.0'
        $request.AllowAutoRedirect = $true
        $request.Timeout = 600000
        $request.ReadWriteTimeout = 600000

        $response = $request.GetResponse()
        try {
            $totalBytes = $response.ContentLength
            $inputStream = $response.GetResponseStream()
            $outputStream = [System.IO.File]::Open($partFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
            try {
                $buffer = New-Object byte[] 65536
                $bytesRead = 0
                $totalRead = 0L

                while (($bytesRead = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $outputStream.Write($buffer, 0, $bytesRead)
                    $totalRead += $bytesRead

                    if ($ShowProgress) {
                        if ($totalBytes -gt 0) {
                            $pct = [math]::Min(100, [int](($totalRead * 100) / $totalBytes))
                            $status = '{0} / {1}' -f (Format-FoFileSize -Bytes $totalRead), (Format-FoFileSize -Bytes $totalBytes)
                            Write-Progress -Activity $activity -Status $status -CurrentOperation $fileName -PercentComplete $pct
                        }
                        else {
                            Write-Progress -Activity $activity -Status (Format-FoFileSize -Bytes $totalRead) -CurrentOperation $fileName
                        }
                    }
                }
            }
            finally {
                $outputStream.Dispose()
                $inputStream.Dispose()
            }
        }
        finally {
            $response.Close()
        }
    }
    catch {
        if (Test-Path -LiteralPath $partFile) {
            Remove-Item -LiteralPath $partFile -Force -ErrorAction SilentlyContinue
        }
        throw "Failed to download FileOptimizer bundle from '$Url'. $($_.Exception.Message)"
    }
    finally {
        if ($ShowProgress) {
            Write-Progress -Activity $activity -Completed
        }
    }

    Move-Item -LiteralPath $partFile -Destination $DestinationFile -Force

    if ($ShowProgress) {
        $size = (Get-Item -LiteralPath $DestinationFile).Length
        Write-Host "Download complete ($(Format-FoFileSize -Bytes $size))."
    }
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
        [switch]$Force,
        [bool]$ShowProgress = $true
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
            Invoke-FoPluginBundleDownload -DestinationFile $archivePath -Url $url -ShowProgress:$ShowProgress
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
