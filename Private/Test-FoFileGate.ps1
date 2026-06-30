function Test-FoPathMask {
    param(
        [string]$Path,
        [string]$Mask
    )
    if ([string]::IsNullOrWhiteSpace($Mask)) { return $true }
    $tokens = $Mask.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    foreach ($t in $tokens) {
        if ($Path -like "*$t*") { return $true }
    }
    return $false
}

function Test-FoFileGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [hashtable]$Settings
    )

    if ($Settings.IncludeMask -and -not (Test-FoPathMask -Path $Path -Mask $Settings.IncludeMask)) {
        return @{ Pass = $false; Reason = 'IncludeMask' }
    }
    if ($Settings.ExcludeMask -and (Test-FoPathMask -Path $Path -Mask $Settings.ExcludeMask)) {
        return @{ Pass = $false; Reason = 'ExcludeMask' }
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @{ Pass = $false; Reason = 'NotFound' }
    }
    return @{ Pass = $true; Reason = $null }
}

function Test-FoIsAPNG {
    param([string]$Path)
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $buf = New-Object byte[] 16
            [void]$fs.Read($buf, 0, 16)
            if ($buf[0] -ne 0x89 -or $buf[1] -ne 0x50) { return $false }
            $text = [System.Text.Encoding]::ASCII.GetString($buf)
            return $text -match 'acTL'
        }
        finally { $fs.Dispose() }
    }
    catch { return $false }
}

function Test-FoIsPNG9Patch {
    param([string]$Path)
    return $Path -like '*.9.png'
}

function Test-FoIsZipSFX {
    param([string]$Path)
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $buf = New-Object byte[] 4
            [void]$fs.Read($buf, 0, 4)
            return ($buf[0] -eq 0x4D -and $buf[1] -eq 0x5A)
        }
        finally { $fs.Dispose() }
    }
    catch { return $false }
}

function New-FoFileContext {
    param(
        [string]$InputFile,
        [hashtable]$Settings
    )

    $ext = [System.IO.Path]::GetExtension($InputFile).ToLowerInvariant()
    $detected = Get-ExtensionByContent -Path $InputFile -Extension $ext

    @{
        InputFile     = $InputFile
        Extension     = $detected
        Settings      = $Settings
        IsAPNG        = (Test-FoIsAPNG -Path $InputFile)
        IsPNG9Patch   = (Test-FoIsPNG9Patch -Path $InputFile)
        IsZipSFX      = (Test-FoIsZipSFX -Path $InputFile)
        IsJPEGCMYK    = $false
        IsPDFLayered  = $false
    }
}
