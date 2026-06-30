#Requires -Version 5.1
<#
.SYNOPSIS
    Builds ExtensionMap.psd1 from FileOptimizer extension-pipeline index markdown.
#>
[CmdletBinding()]
param(
    [string]$InputPath = 'D:\Projects\FileOptimizerAnalisys\Docs\KnowlegeBase\11-extension-pipeline-index.md',
    [string]$OutputPath = 'D:\Projects\PS-FileOptimizer\Data\ExtensionMap.psd1'
)

$ErrorActionPreference = 'Stop'

# Markdown pipeline group name -> PS1 pipeline file ID (no slashes)
$PipelineMap = @{
    'PNG/APNG'       = 'PNG'
    'JPEG'           = 'JPEG'
    'PDF'            = 'PDF'
    'ZIP/archives'   = 'ZIP'
    'GIF'            = 'GIF'
    'OLE/Office'     = 'OLE'
    'Misc images'    = 'MISC'
    'SQLite'         = 'SQLite'
    'TIFF/DNG'       = 'TIFF'
    'DLL/PE'         = 'DLL'
    'EXE'            = 'EXE'
    'GZIP'           = 'GZIP'
    'HTML'           = 'HTML'
    'CSS'            = 'CSS'
    'JS/JSON'        = 'JS'
    'XML'            = 'XML'
    'MIME/email'     = 'MIME'
    'Ogg'            = 'OGG'
    'Ogg video'      = 'OGV'
    '7-Zip'          = 'SevenZip'
    'AVIF/HEIF'      = 'AVIF'
    'BMP'            = 'BMP'
    'ICO'            = 'ICO'
    'FLAC'           = 'FLAC'
    'Matroska/WebM'  = 'MKV'
    'Flash SWF'      = 'SWF'
    'TAR'            = 'TAR'
    'TGA'            = 'TGA'
    'WebP'           = 'WebP'
    'WAV'            = 'WAV'
    'PCX'            = 'PCX'
    'OBJ/static lib' = 'OBJ'
    'Tencent QQ'     = 'TencentQQ'
    'Lua'            = 'Lua'
    'MP4/video'      = 'MP4'
    'JPEG2000'       = 'JPEG2000'
    'JPEG XL'        = 'JPEGXL'
    'MNG'            = 'MNG'
    'MP3'            = 'MP3'
}

function ConvertTo-PipelineIds {
    param([string]$PipelineCell)

    $normalized = $PipelineCell -replace '`', ''
    $parts = $normalized -split '\s*\+\s*|\s*,\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $ids = [System.Collections.Generic.List[string]]::new()

    foreach ($part in $parts) {
        if (-not $PipelineMap.ContainsKey($part)) {
            throw "Unknown pipeline group '$part' (from '$PipelineCell'). Update `$PipelineMap in this script."
        }
        $id = $PipelineMap[$part]
        if ($ids -notcontains $id) {
            $ids.Add($id) | Out-Null
        }
    }

    return @($ids)
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input file not found: $InputPath"
}

$content = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8
$sectionMarker = '## Complete extension index'
$start = $content.IndexOf($sectionMarker, [StringComparison]::Ordinal)
if ($start -lt 0) {
    throw "Section '$sectionMarker' not found in $InputPath"
}
$section = $content.Substring($start)

$rowPattern = '\|\s*`(?<ext>\.[^`]+)`\s*\|\s*(?<pipelines>[^|]+?)\s*\|'
$matches = [regex]::Matches($section, $rowPattern)

$extensionMap = [ordered]@{}
foreach ($m in $matches) {
    $ext = $m.Groups['ext'].Value.Trim()
    $pipelineCell = $m.Groups['pipelines'].Value.Trim()

    if ($ext -eq 'Extension' -or $pipelineCell -eq 'Pipeline(s)') {
        continue
    }

    $ids = ConvertTo-PipelineIds -PipelineCell $pipelineCell
    if ($ids.Count -eq 0) {
        throw "No pipelines resolved for extension $ext (cell: $pipelineCell)"
    }

    if ($extensionMap.Contains($ext)) {
        throw "Duplicate extension row: $ext"
    }

    $extensionMap[$ext] = $ids
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('@{') | Out-Null
foreach ($ext in ($extensionMap.Keys | Sort-Object)) {
    $idList = ($extensionMap[$ext] | ForEach-Object { "'$_'" }) -join ', '
    $lines.Add("    '$ext' = @($idList)") | Out-Null
}
$lines.Add('}') | Out-Null

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($OutputPath, $lines, $utf8NoBom)

Write-Output $extensionMap.Count
