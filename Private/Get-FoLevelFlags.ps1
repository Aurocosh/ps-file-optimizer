function Get-FoLeanifyIterations {
    param([int]$Level, [int]$Override = -1)
    if ($Override -ne -1) { return $Override }
    return [int](([math]::Pow($Level, 3) / 25) + 1)
}

function Get-FoUPXFlags {
    param([int]$Level)
    if ($Level -lt 3) { return '-1' }
    if ($Level -lt 5) { return '-9' }
    if ($Level -lt 7) { return '-9 --best' }
    if ($Level -lt 9) { return '-9 --best --lzma' }
    return '-9 --best --lzma --ultra-brute'
}

function Get-FoECTPreset {
    param([int]$Level)
    if ($Level -ge 9) { return '90032' }
    return [string]($Level * 10000 + 32)
}

function Get-FoFlacFlags {
    param([int]$Level)
    if ($Level -lt 3) { return '-1' }
    if ($Level -lt 5) { return '-8 --best' }
    if ($Level -lt 7) { return '-e' }
    if ($Level -lt 9) { return '-ep' }
    return '-ep'
}

function Get-FoTruePngLevel {
    param([int]$Level)
    return [math]::Min($Level * 3 / 9, 3) + 1
}

function Get-FoPngOutLevel {
    param([int]$Level)
    return [math]::Max(($Level * 3 / 9) - 3, 0)
}

function Get-FoOxiPngLevel {
    param([int]$Level)
    return [math]::Min($Level * 6 / 9, 6)
}
