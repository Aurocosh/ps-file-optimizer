# Bootstrap 7-Zip command-line tool used only to open the FO SFX as an archive (never executed).
$script:Fo7zrBootstrapUrl = 'https://www.7-zip.org/a/7zr.exe'

function Resolve-Fo7ZipExecutable {
    [CmdletBinding()]
    param(
        [string]$BootstrapDirectory
    )

    $candidates = @(
        (Get-Command '7z.exe' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
        (Get-Command '7z' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
        "${env:ProgramFiles}\7-Zip\7z.exe"
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    if ($candidates) {
        return [PSCustomObject]@{
            Path       = $candidates[0]
            Bootstrapped = $false
        }
    }

    if (-not $BootstrapDirectory) {
        $BootstrapDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "FoPluginInstall_$(Get-Random)"
    }
    if (-not (Test-Path -LiteralPath $BootstrapDirectory)) {
        New-Item -ItemType Directory -Path $BootstrapDirectory -Force | Out-Null
    }

    $bootstrapPath = Join-Path $BootstrapDirectory '7zr.exe'
    if (-not (Test-Path -LiteralPath $bootstrapPath)) {
        Write-Verbose "Downloading 7zr.exe bootstrap from $($script:Fo7zrBootstrapUrl)"
        try {
            Invoke-WebRequest -Uri $script:Fo7zrBootstrapUrl -OutFile $bootstrapPath -UseBasicParsing -ErrorAction Stop
        }
        catch {
            throw "Could not download 7zr.exe bootstrap. Install 7-Zip or ensure outbound HTTPS to www.7-zip.org is allowed. $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]@{
        Path         = $bootstrapPath
        Bootstrapped = $true
    }
}

function Expand-Fo7zArchive {
    <#
    .SYNOPSIS
    Extracts a 7z archive or 7z SFX (.7z.exe) without running the self-extractor stub.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ArchivePath,
        [Parameter(Mandatory)]
        [string]$DestinationPath,
        [string]$SevenZipPath,
        [switch]$PassThru
    )

    if (-not (Test-Path -LiteralPath $ArchivePath)) {
        throw "Archive not found: $ArchivePath"
    }

    $bootstrapDir = Join-Path ([System.IO.Path]::GetDirectoryName($ArchivePath)) '7z-bootstrap'
    if ($SevenZipPath) {
        $sevenZip = $SevenZipPath
        $bootstrapped = $false
    }
    else {
        $resolved = Resolve-Fo7ZipExecutable -BootstrapDirectory $bootstrapDir
        $sevenZip = $resolved.Path
        $bootstrapped = $resolved.Bootstrapped
    }

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }

    $outArg = "-o$DestinationPath"
    $args = @('x', '-y', $outArg, $ArchivePath)

    Write-Verbose "Extracting with: $sevenZip $($args -join ' ')"
    & $sevenZip @args | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip extraction failed (exit code $LASTEXITCODE). Archive: $ArchivePath"
    }

    if ($PassThru) {
        return [PSCustomObject]@{
            SevenZipPath   = $sevenZip
            Bootstrapped   = [bool]$bootstrapped
            BootstrapDir   = if ($bootstrapped) { $bootstrapDir } else { $null }
            DestinationPath = $DestinationPath
        }
    }
}
