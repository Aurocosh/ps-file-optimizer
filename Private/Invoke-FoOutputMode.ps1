function Get-FoBackupRelativePath {
    param(
        [Parameter(Mandatory)]
        [string]$TargetPath,
        [string]$BaseDirectory
    )

    $target = [System.IO.Path]::GetFullPath($TargetPath)
    if (-not $BaseDirectory) {
        $BaseDirectory = [System.IO.Path]::GetPathRoot($target)
    }
    $prefix = [System.IO.Path]::GetFullPath($BaseDirectory)
    if (-not $prefix.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $prefix += [System.IO.Path]::DirectorySeparatorChar
    }

    if ($target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $target.Substring($prefix.Length)
    }

    $hash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA1]::Create().ComputeHash(
            [System.Text.Encoding]::UTF8.GetBytes($target.ToLowerInvariant())
        )
    ).Replace('-', '').ToLowerInvariant()
    return Join-Path $hash ([System.IO.Path]::GetFileName($target))
}

function Invoke-FoPromoteOptimizedFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceFile,
        [Parameter(Mandatory)]
        [string]$TargetPath,
        [string]$BackupDestination
    )

    $staging = $TargetPath + '.fo-staging'
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Force
    }

    $movedToBackup = $false
    try {
        Copy-Item -LiteralPath $SourceFile -Destination $staging -Force

        if ($BackupDestination) {
            $bakDir = Split-Path -Parent $BackupDestination
            if ($bakDir -and -not (Test-Path -LiteralPath $bakDir)) {
                New-Item -ItemType Directory -Path $bakDir -Force | Out-Null
            }
            if (Test-Path -LiteralPath $TargetPath) {
                Move-Item -LiteralPath $TargetPath -Destination $BackupDestination -Force
                $movedToBackup = $true
            }
        }

        Move-Item -LiteralPath $staging -Destination $TargetPath -Force
    }
    catch {
        if ($movedToBackup -and -not (Test-Path -LiteralPath $TargetPath) -and (Test-Path -LiteralPath $BackupDestination)) {
            Move-Item -LiteralPath $BackupDestination -Destination $TargetPath -Force
        }
        if (Test-Path -LiteralPath $staging) {
            Remove-Item -LiteralPath $staging -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

function Invoke-FoCopyOptimizedFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceFile,
        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    $staging = $DestinationPath + '.fo-staging'
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Force
    }

    try {
        Copy-Item -LiteralPath $SourceFile -Destination $staging -Force
        Move-Item -LiteralPath $staging -Destination $DestinationPath -Force
    }
    catch {
        if (Test-Path -LiteralPath $staging) {
            Remove-Item -LiteralPath $staging -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $DestinationPath) {
            $destLen = (Get-Item -LiteralPath $DestinationPath).Length
            $srcLen = (Get-Item -LiteralPath $SourceFile).Length
            if ($destLen -ne $srcLen) {
                Remove-Item -LiteralPath $DestinationPath -Force -ErrorAction SilentlyContinue
            }
        }
        throw
    }
}

function Invoke-FoOutputMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceFile,
        [Parameter(Mandatory)]
        [string]$TargetPath,
        [Parameter(Mandatory)]
        [hashtable]$Settings
    )

    $mode = $Settings.OutputMode
    $target = [System.IO.Path]::GetFullPath($TargetPath)
    $dir = Split-Path -Parent $target
    $name = [System.IO.Path]::GetFileName($target)

    $result = @{
        OptimizedPath = $target
        OriginalPath  = $target
        BackupPath    = $null
    }

    switch ($mode) {
        'Replace' {
            Invoke-FoPromoteOptimizedFile -SourceFile $SourceFile -TargetPath $target
        }
        'OptimizedSuffix' {
            $suffix = $Settings.OptimizedSuffix
            $base = [System.IO.Path]::GetFileNameWithoutExtension($target)
            $ext = [System.IO.Path]::GetExtension($target)
            $outPath = Join-Path $dir ($base + $suffix + $ext)
            Invoke-FoCopyOptimizedFile -SourceFile $SourceFile -DestinationPath $outPath
            $result.OptimizedPath = $outPath
            $result.OriginalPath = $target
        }
        'BackupSuffix' {
            $bak = $target + $Settings.BackupSuffix
            Invoke-FoPromoteOptimizedFile -SourceFile $SourceFile -TargetPath $target -BackupDestination $bak
            $result.BackupPath = $bak
            $result.OriginalPath = $bak
        }
        'BackupMove' {
            if (-not $Settings.BackupPath) { throw 'BackupMove requires BackupPath.' }
            $rel = Get-FoBackupRelativePath -TargetPath $target
            $bakDest = Join-Path $Settings.BackupPath $rel
            Invoke-FoPromoteOptimizedFile -SourceFile $SourceFile -TargetPath $target -BackupDestination $bakDest
            $result.BackupPath = $bakDest
            $result.OriginalPath = $bakDest
        }
        'TempMove' {
            $root = $Settings.TempBackupPath
            if (-not $root) { $root = Join-Path $env:TEMP 'FileOptimizer\backups' }
            $rel = Get-FoBackupRelativePath -TargetPath $target
            $bakDest = Join-Path $root $rel
            Invoke-FoPromoteOptimizedFile -SourceFile $SourceFile -TargetPath $target -BackupDestination $bakDest
            $result.BackupPath = $bakDest
            $result.OriginalPath = $bakDest
        }
        default { throw "Unknown OutputMode: $mode" }
    }

    return [PSCustomObject]$result
}
