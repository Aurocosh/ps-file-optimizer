function Get-ExtensionByContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$Extension,
        [switch]$Force
    )

    $ext = if ($Extension) { $Extension.ToLowerInvariant() } else { '' }
    $mapPath = if ($script:FoModuleRoot) { Join-Path $script:FoModuleRoot 'Data\ExtensionMap.psd1' } else { $null }
    $allExts = @()
    if ($mapPath -and (Test-Path -LiteralPath $mapPath)) {
        $allExts = (Import-FoDataFile -Path $mapPath).Keys
    }

    $needsDetect = $Force -or -not $ext -or ($ext -notin $allExts)
    if (-not $needsDetect) { return $ext }
    if (-not (Test-Path -LiteralPath $Path)) { return $ext }

    $fs = [System.IO.File]::OpenRead($Path)
    try {
        $head = New-Object byte[] 512
        $read = $fs.Read($head, 0, 512)
        if ($read -lt 4) { return $ext }

        $tail = New-Object byte[] 512
        $fs.Seek([math]::Max(0, $fs.Length - 512), [System.IO.SeekOrigin]::Begin) | Out-Null
        [void]$fs.Read($tail, 0, 512)

        $ascii = [System.Text.Encoding]::ASCII.GetString($head)

        if ($ascii.StartsWith("`0`0`0") -and $ascii.Substring(4, 4) -match 'ftyp') { return '.avif' }
        if ($head[0] -eq 0x42 -and $head[1] -eq 0x4D) { return '.bmp' }
        if ($head[0] -eq 0x4D -and $head[1] -eq 0x5A) { return '.exe' }
        if ($ascii.StartsWith('fLaC')) { return '.flac' }
        if ($ascii.StartsWith('GIF87a') -or $ascii.StartsWith('GIF89a')) { return '.gif' }
        if ($head[0] -eq 0x1F -and $head[1] -eq 0x8B) { return '.gz' }
        if ($head[0] -eq 0x00 -and $head[1] -eq 0x00 -and $head[2] -eq 0x01 -and $head[3] -eq 0x00) { return '.ico' }
        if ($ascii.StartsWith("`0`0`0`f jP  ")) { return '.jp2' }
        if ($head[0] -eq 0xFF -and $head[1] -eq 0xD8) { return '.jpg' }
        if ($ascii.Contains('matroska') -or $ascii.Contains('webm')) { return '.mkv' }
        if ($ascii.StartsWith('MNG')) { return '.mng' }
        if ($ascii.StartsWith('ID3') -or ($head[0] -eq 0xFF -and ($head[1] -band 0xE0) -eq 0xE0)) { return '.mp3' }
        if ($ascii.Contains('ftyp') -or $ascii.Contains('moov')) { return '.mp4' }
        if ($ascii.StartsWith('OggS')) { return '.ogg' }
        if ($head[0] -eq 0xD0 -and $head[1] -eq 0xCF) { return '.doc' }
        if ($head[0] -eq 0x0A -and $head[1] -eq 0x05) { return '.pcx' }
        if ($ascii.StartsWith('%PDF')) { return '.pdf' }
        if ($head[0] -eq 0x89 -and $head[1] -eq 0x50 -and $head[2] -eq 0x4E -and $head[3] -eq 0x47) { return '.png' }
        if ($ascii.StartsWith('SQLite format 3')) { return '.db' }
        if ($ascii.StartsWith('FWS') -or $ascii.StartsWith('CWS')) { return '.swf' }
        if ($ascii.StartsWith('ustar')) { return '.tar' }
        if ($ascii.StartsWith('RIFF') -and $ascii.Contains('WEBP')) { return '.webp' }
        if ($ascii.StartsWith('RIFF') -and $ascii.Contains('WAVE')) { return '.wav' }
        if ($head[0] -eq 0x50 -and $head[1] -eq 0x4B) { return '.zip' }
        if ($head[0] -eq 0x37 -and $head[1] -eq 0x7A) { return '.7z' }
        if ($head[0] -eq 0x49 -and $head[1] -eq 0x49 -and $head[2] -eq 0x2A -and $head[3] -eq 0x00) { return '.tif' }
        if ($head[0] -eq 0x4D -and $head[1] -eq 0x4D -and $head[2] -eq 0x00 -and $head[3] -eq 0x2A) { return '.tif' }
    }
    finally { $fs.Dispose() }

    return $ext
}

function Get-FoExtensionMap {
    if (-not $script:FoExtensionMap) {
        $path = Join-Path $script:FoModuleRoot 'Data\ExtensionMap.psd1'
        $script:FoExtensionMap = Import-FoDataFile -Path $path
    }
    return $script:FoExtensionMap
}

function Get-FoPipelineGroupsForFile {
    param([string]$Path)

    $ext = Get-ExtensionByContent -Path $Path
    if (-not $ext) { return @() }
    $map = Get-FoExtensionMap
    if ($map -and $map.ContainsKey($ext)) {
        return @($map[$ext])
    }
    return @()
}
