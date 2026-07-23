function Test-FoBufferBytes {
    param(
        [byte[]]$Buffer,
        [int]$Offset,
        [byte[]]$Pattern
    )

    if ($null -eq $Buffer -or $null -eq $Pattern) { return $false }
    if ($Offset -lt 0 -or $Pattern.Length -eq 0) { return $false }
    if ($Buffer.Length -lt ($Offset + $Pattern.Length)) { return $false }

    for ($i = 0; $i -lt $Pattern.Length; $i++) {
        if ($Buffer[$Offset + $i] -ne $Pattern[$i]) { return $false }
    }
    return $true
}

function Test-FoBufferAscii {
    param(
        [byte[]]$Buffer,
        [int]$Offset,
        [string]$Text
    )

    $pattern = [System.Text.Encoding]::ASCII.GetBytes($Text)
    return Test-FoBufferBytes -Buffer $Buffer -Offset $Offset -Pattern $pattern
}

function Get-ExtensionByContent {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$Extension,
        [switch]$Force,
        [hashtable]$Settings
    )

    $ext = if ($Extension) { $Extension.ToLowerInvariant() } else { '' }
    $mapPath = if ($script:FoModuleRoot) { Join-Path $script:FoModuleRoot 'Data\ExtensionMap.psd1' } else { $null }
    $allExts = @()
    if ($mapPath -and (Test-Path -LiteralPath $mapPath)) {
        $allExts = @((Import-FoPsd1File -Path $mapPath).Keys)
    }
    if ($Settings -and $Settings.JSAdditionalExtensions) {
        foreach ($token in ($Settings.JSAdditionalExtensions.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
            $normalized = if ($token.StartsWith('.')) { $token.ToLowerInvariant() } else { ('.' + $token).ToLowerInvariant() }
            if ($normalized -notin $allExts) { $allExts += $normalized }
        }
    }

    $needsDetect = $Force -or -not $ext -or ($ext -notin $allExts)
    if (-not $needsDetect) { return $ext }
    if (-not (Test-Path -LiteralPath $Path)) { return $ext }

    $fs = [System.IO.File]::OpenRead($Path)
    try {
        $head = New-Object byte[] 512
        $read = $fs.Read($head, 0, 512)
        if ($read -lt 4) { return '' }

        $tail = New-Object byte[] 512
        $tailRead = 0
        if ($fs.Length -gt 0) {
            $fs.Seek([math]::Max(0, $fs.Length - 512), [System.IO.SeekOrigin]::Begin) | Out-Null
            $tailRead = $fs.Read($tail, 0, 512)
        }

        if (Test-FoBufferAscii -Buffer $head -Offset 4 -Text 'ftyp') { return '.avif' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'BM') { return '.bmp' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'BA') { return '.bmp' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'CI') { return '.bmp' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'CP') { return '.bmp' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'IC') { return '.bmp' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'PT') { return '.bmp' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'MZ') { return '.dll' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'ZM') { return '.dll' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'fLaC') { return '.flac' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'GIF8') { return '.gif' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x1F, 0x8B, 0x08))) { return '.gz' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x00, 0x00, 0x01, 0x00))) { return '.ico' }
        if (Test-FoBufferAscii -Buffer $head -Offset 4 -Text 'jP') { return '.jp2' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0xFF, 0xD8, 0xFF))) { return '.jpg' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x00, 0x00, 0x00, 0x0C, 0x4A, 0x58, 0x4C, 0x20, 0x0D, 0x0A, 0x87, 0x0A))) { return '.jxl' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text '.RTS') { return '.mkv' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x8A, 0x4D, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A))) { return '.mng' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'ID3') { return '.mp3' }
        if (Test-FoBufferAscii -Buffer $head -Offset 3 -Text 'ftyp') { return '.mp4' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x4C, 0x01))) { return '.obj' }
        if ($head[0] -eq 0x80) { return '.obj' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'OggS') { return '.ogg' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1))) { return '.ole' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x0E, 0x11, 0xFC, 0x0D, 0xD0, 0xCF, 0x11, 0x0E))) { return '.ole' }
        if ($read -ge 75 -and $head[0] -eq 10 -and $head[2] -eq 1 -and $head[64] -eq 0 -and $head[74] -eq 0) { return '.pcx' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text '%PDF-') { return '.pdf' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A))) { return '.png' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'SQLite format 3') { return '.sqlite' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'FWS') { return '.swf' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'CWS') { return '.swf' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'ZWS') { return '.swf' }
        if ($read -ge 262 -and (Test-FoBufferBytes -Buffer $head -Offset 257 -Pattern ([byte[]](0x75, 0x73, 0x74, 0x61, 0x72)))) { return '.tar' }
        if ($tailRead -ge 504 -and (Test-FoBufferAscii -Buffer $tail -Offset 494 -Text 'TRUEVISION')) { return '.tga' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x0C, 0xED))) { return '.tif' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x49, 0x20, 0x49))) { return '.tif' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x49, 0x49, 0x2A, 0x00))) { return '.tif' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x4D, 0x4D, 0x00, 0x2B))) { return '.tif' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'RIFF') { return '.wav' }
        if (Test-FoBufferAscii -Buffer $head -Offset 7 -Text 'WEBP') { return '.webp' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x50, 0x4B, 0x03, 0x04))) { return '.zip' }
        if (Test-FoBufferAscii -Buffer $head -Offset 0 -Text 'MSCF') { return '.cab' }
        if (Test-FoBufferBytes -Buffer $head -Offset 0 -Pattern ([byte[]](0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C))) { return '.7z' }
    }
    finally { $fs.Dispose() }

    return ''
}

function Get-FoExtensionMap {
    if (-not $script:FoExtensionMap) {
        $path = Join-Path $script:FoModuleRoot 'Data\ExtensionMap.psd1'
        $script:FoExtensionMap = Import-FoPsd1File -Path $path
    }
    return $script:FoExtensionMap
}

function Get-FoPipelineGroupsForFile {
    param(
        [string]$Path,
        [hashtable]$Settings
    )

    $pathExt = [System.IO.Path]::GetExtension($Path)
    $ext = Get-ExtensionByContent -Path $Path -Extension $pathExt -Settings $Settings
    if (-not $ext) { return @() }
    $map = Get-FoExtensionMap
    if ($map -and $map.ContainsKey($ext)) {
        return @($map[$ext])
    }
    if ($Settings -and $Settings.JSAdditionalExtensions) {
        foreach ($token in ($Settings.JSAdditionalExtensions.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
            $normalized = if ($token.StartsWith('.')) { $token.ToLowerInvariant() } else { ('.' + $token).ToLowerInvariant() }
            if ($ext -eq $normalized) { return @('JS') }
        }
    }
    return @()
}
