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
            Copy-Item -LiteralPath $SourceFile -Destination $target -Force
        }
        'OptimizedSuffix' {
            $suffix = $Settings.OptimizedSuffix
            $base = [System.IO.Path]::GetFileNameWithoutExtension($target)
            $ext = [System.IO.Path]::GetExtension($target)
            $outPath = Join-Path $dir ($base + $suffix + $ext)
            Copy-Item -LiteralPath $SourceFile -Destination $outPath -Force
            $result.OptimizedPath = $outPath
            $result.OriginalPath = $target
        }
        'BackupSuffix' {
            $bak = $target + $Settings.BackupSuffix
            if (Test-Path -LiteralPath $target) {
                Move-Item -LiteralPath $target -Destination $bak -Force
            }
            Copy-Item -LiteralPath $SourceFile -Destination $target -Force
            $result.BackupPath = $bak
            $result.OriginalPath = $bak
        }
        'BackupMove' {
            if (-not $Settings.BackupPath) { throw 'BackupMove requires BackupPath.' }
            $rel = if ($target.StartsWith((Get-Location).Path)) {
                $target.Substring((Get-Location).Path.Length).TrimStart('\', '/')
            }
            else { $name }
            $bakDest = Join-Path $Settings.BackupPath $rel
            $bakDir = Split-Path -Parent $bakDest
            if ($bakDir -and -not (Test-Path -LiteralPath $bakDir)) {
                New-Item -ItemType Directory -Path $bakDir -Force | Out-Null
            }
            if (Test-Path -LiteralPath $target) {
                Move-Item -LiteralPath $target -Destination $bakDest -Force
            }
            Copy-Item -LiteralPath $SourceFile -Destination $target -Force
            $result.BackupPath = $bakDest
            $result.OriginalPath = $bakDest
        }
        'TempMove' {
            $root = $Settings.TempBackupPath
            if (-not $root) { $root = Join-Path $env:TEMP 'FileOptimizer\backups' }
            $rel = if ($dir) {
                $leaf = Split-Path -Path (Get-Location) -Leaf
                Join-Path $leaf $name
            }
            else { $name }
            $bakDest = Join-Path $root $rel
            $bakDir = Split-Path -Parent $bakDest
            if ($bakDir -and -not (Test-Path -LiteralPath $bakDir)) {
                New-Item -ItemType Directory -Path $bakDir -Force | Out-Null
            }
            if (Test-Path -LiteralPath $target) {
                Move-Item -LiteralPath $target -Destination $bakDest -Force
            }
            Copy-Item -LiteralPath $SourceFile -Destination $target -Force
            $result.BackupPath = $bakDest
            $result.OriginalPath = $bakDest
        }
        default { throw "Unknown OutputMode: $mode" }
    }

    return [PSCustomObject]$result
}
