function Test-FoImageTestRelativePathExcluded {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath,
        [string[]]$ExcludedPatterns
    )

    $normalized = ($RelativePath -replace '\\', '/').TrimStart('./')
    foreach ($pattern in $ExcludedPatterns) {
        $glob = ($pattern -replace '\\', '/')
        if ($glob -match '\*\*') {
            $prefix = ($glob -split '\*\*')[0]
            if ($normalized.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
            continue
        }
        if ($glob -match '[\*\?\[\]]') {
            if ($normalized -like $glob) { return $true }
        }
        elseif ($normalized -ieq $glob) {
            return $true
        }
    }
    return $false
}

function Get-FoImageTestTierRelativePaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('B', 'C', 'D')]
        [string]$Tier,
        [Parameter(Mandatory)]
        [string]$UpstreamRoot
    )

    $upstreamRoot = [System.IO.Path]::GetFullPath($UpstreamRoot)
    if (-not (Test-Path -LiteralPath $upstreamRoot)) {
        throw "Upstream path not found: $upstreamRoot"
    }

    $moduleRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $moduleRoot 'Private\Import-FoDataFile.ps1')
    $manifest = Import-FoDataFile -Path (Join-Path $moduleRoot 'Tests\ImageTestManifest.psd1')
    $excluded = @($manifest.Excluded)

    $results = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    function Add-RelativePath {
        param([string]$RelativePath)
        $rel = ($RelativePath -replace '\\', '/').TrimStart('./')
        if (-not $rel) { return }
        if (Test-FoImageTestRelativePathExcluded -RelativePath $rel -ExcludedPatterns $excluded) {
            return
        }
        [void]$results.Add($rel)
    }

    function Add-FilesFromGlob {
        param(
            [string]$GlobPattern,
            [int]$MaxBytes = 0
        )
        $pattern = $GlobPattern -replace '/', [System.IO.Path]::DirectorySeparatorChar
        $searchRoot = $upstreamRoot
        $filePattern = Split-Path -Leaf $pattern
        $dirPart = Split-Path -Parent $pattern
        if ($dirPart) {
            $searchRoot = Join-Path $upstreamRoot $dirPart
        }
        if (-not (Test-Path -LiteralPath $searchRoot)) {
            return
        }
        Get-ChildItem -LiteralPath $searchRoot -Recurse -File -Filter $filePattern -ErrorAction SilentlyContinue |
            ForEach-Object {
                if ($MaxBytes -gt 0 -and $_.Length -gt $MaxBytes) { return }
                $rel = $_.FullName.Substring($upstreamRoot.Length).TrimStart('\', '/')
                Add-RelativePath $rel
            }
    }

    switch ($Tier) {
        'B' {
            Get-ChildItem -LiteralPath (Join-Path $upstreamRoot 'pngsuite') -File -Filter '*.png' -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notlike 'x*' } |
                ForEach-Object { Add-RelativePath ('pngsuite/' + $_.Name) }

            Add-FilesFromGlob 'gif-conformance/valid/*'
            Add-FilesFromGlob 'apng-conformance/valid/*'
            Add-FilesFromGlob 'jpeg-conformance/valid/*' -MaxBytes 204800
            Add-FilesFromGlob 'mozjpeg/*.jpg'
            Add-FilesFromGlob 'mozjpeg/*.bmp'

            foreach ($name in @('2-color.webp', 'simple-rgb.webp', 'simple-gray.webp', 'anim.webp', 'lossy_alpha.webp')) {
                Add-RelativePath "webp-conformance/valid/$name"
            }

            Add-FilesFromGlob 'bmp-conformance/valid/*' -MaxBytes 20480
            Add-FilesFromGlob 'image-rs/test-images/jpg/**/*.jpg'
            Add-RelativePath 'image-rs/test-images/tiff/testsuite/l1.tiff'
            Add-RelativePath 'gb82-sc/windows95.png'
            Add-RelativePath 'gb82-sc/graph.png'
        }
        'C' {
            Add-FilesFromGlob 'gb82/*-lossless.png'
        }
        'D' {
            Get-ChildItem -LiteralPath (Join-Path $upstreamRoot 'gb82-sc') -File -Filter '*.png' -ErrorAction SilentlyContinue |
                ForEach-Object { Add-RelativePath ('gb82-sc/' + $_.Name) }

            foreach ($name in @('mc3-lossless.png', 'pixel-lossless.png', 'house-lossless.png', 'haze-lossless.png', 'baby-lossless.png')) {
                Add-RelativePath "gb82/$name"
            }
        }
    }

    return @($results | Sort-Object)
}
