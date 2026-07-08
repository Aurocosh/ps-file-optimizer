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
            $br = New-Object System.IO.BinaryReader($fs)
            $sig = $br.ReadBytes(8)
            if ($sig.Length -lt 8) { return $false }
            $pngSig = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
            for ($i = 0; $i -lt 8; $i++) {
                if ($sig[$i] -ne $pngSig[$i]) { return $false }
            }

            while ($fs.Position -lt $fs.Length) {
                if (($fs.Length - $fs.Position) -lt 8) { return $false }
                $lenBytes = $br.ReadBytes(4)
                $length = ([uint32]$lenBytes[0] -shl 24) -bor ([uint32]$lenBytes[1] -shl 16) -bor ([uint32]$lenBytes[2] -shl 8) -bor [uint32]$lenBytes[3]
                $type = [System.Text.Encoding]::ASCII.GetString($br.ReadBytes(4))
                if ($type -eq 'acTL' -or $type -eq 'fcTL' -or $type -eq 'fdAT') {
                    return $true
                }
                $skip = [int64]$length + 4
                if ($skip -lt 0 -or ($fs.Position + $skip) -gt $fs.Length) { return $false }
                if ($skip -gt 0) { $fs.Position += $skip }
            }
            return $false
        }
        finally { $fs.Dispose() }
    }
    catch { return $false }
}

function Test-FoIsPNG9Patch {
    param([string]$Path)

    if ($Path -like '*.9.png') { return $true }

    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $br = New-Object System.IO.BinaryReader($fs)
            $sig = $br.ReadBytes(8)
            if ($sig.Length -lt 8) { return $false }
            $pngSig = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
            for ($i = 0; $i -lt 8; $i++) {
                if ($sig[$i] -ne $pngSig[$i]) { return $false }
            }

            while ($fs.Position -lt $fs.Length) {
                if (($fs.Length - $fs.Position) -lt 8) { return $false }
                $lenBytes = $br.ReadBytes(4)
                $length = ([uint32]$lenBytes[0] -shl 24) -bor ([uint32]$lenBytes[1] -shl 16) -bor ([uint32]$lenBytes[2] -shl 8) -bor [uint32]$lenBytes[3]
                $type = [System.Text.Encoding]::ASCII.GetString($br.ReadBytes(4))
                if ($type -eq 'npTc' -or $type -eq 'npLb') {
                    return $true
                }
                $skip = [int64]$length + 4
                if ($skip -lt 0 -or ($fs.Position + $skip) -gt $fs.Length) { return $false }
                if ($skip -gt 0) { $fs.Position += $skip }
            }
            return $false
        }
        finally { $fs.Dispose() }
    }
    catch { return $false }
}

function Get-FoFileHeaderBytes {
    param(
        [string]$Path,
        [int]$MaxBytes = 524288
    )

    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $len = [Math]::Min($MaxBytes, $fs.Length)
            if ($len -le 0) { return $null }
            $buf = New-Object byte[] $len
            [void]$fs.Read($buf, 0, $len)
            return $buf
        }
        finally { $fs.Dispose() }
    }
    catch { return $null }
}

function Test-FoBufferContainsBytes {
    param(
        [byte[]]$Buffer,
        [byte[]]$Pattern
    )

    if (-not $Buffer -or -not $Pattern -or $Pattern.Length -eq 0 -or $Buffer.Length -lt $Pattern.Length) {
        return $false
    }

    for ($i = 0; $i -le ($Buffer.Length - $Pattern.Length); $i++) {
        $matched = $true
        for ($j = 0; $j -lt $Pattern.Length; $j++) {
            if ($Buffer[$i + $j] -ne $Pattern[$j]) {
                $matched = $false
                break
            }
        }
        if ($matched) { return $true }
    }
    return $false
}

function Test-FoBufferContainsAscii {
    param(
        [byte[]]$Buffer,
        [string]$Text
    )

    if (-not $Buffer -or [string]::IsNullOrEmpty($Text)) { return $false }
    $pattern = [System.Text.Encoding]::ASCII.GetBytes($Text)
    return Test-FoBufferContainsBytes -Buffer $Buffer -Pattern $pattern
}

function Test-FoIsEXESFX {
    param([string]$Path)

    $buf = Get-FoFileHeaderBytes -Path $Path -MaxBytes 1048576
    if (-not $buf -or $buf.Length -lt 2) { return $false }
    if (-not (Test-FoBufferContainsBytes -Buffer $buf -Pattern ([byte[]](0x4D, 0x5A))) -and
        -not (Test-FoBufferContainsBytes -Buffer $buf -Pattern ([byte[]](0x5A, 0x4D)))) {
        return $false
    }

    foreach ($marker in @(
            'Inno Setup'
            'InstallShield'
            'Nullsoft Install System'
            'RTPatch'
        )) {
        if (Test-FoBufferContainsAscii -Buffer $buf -Text $marker) { return $true }
    }

    foreach ($pattern in @(
            [byte[]](0x52, 0x61, 0x72, 0x21, 0x1A, 0x07)
            [byte[]](0x50, 0x4B, 0x03, 0x04)
            [byte[]](0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C)
            [byte[]](0x4D, 0x53, 0x43, 0x46)
        )) {
        if (Test-FoBufferContainsBytes -Buffer $buf -Pattern $pattern) { return $true }
    }

    return $false
}

function Test-FoIsZipSFX {
    param([string]$Path)
    return Test-FoIsEXESFX -Path $Path
}

function Test-FoIsPDFLayered {
    param([string]$Path)

    $buf = Get-FoFileHeaderBytes -Path $Path -MaxBytes 524288
    if (-not $buf) { return $false }
    return Test-FoBufferContainsAscii -Buffer $buf -Text '<< /Type /OCG /Name'
}

function Test-FoIsJPEGCMYK {
    param([string]$Path)

    $buf = Get-FoFileHeaderBytes -Path $Path -MaxBytes 524288
    if (-not $buf) { return $false }

    $sof0 = [byte[]](0xFF, 0xC0)
    $sof2 = [byte[]](0xFF, 0xC2)
    $start = 0
    while ($true) {
        $idx = -1
        for ($i = $start; $i -le ($buf.Length - 2); $i++) {
            if ($buf[$i] -eq 0xFF -and $buf[$i + 1] -eq 0xC0) {
                $idx = $i
                break
            }
        }
        if ($idx -lt 0) { return $false }

        $searchFrom = $idx
        $progIdx = -1
        for ($i = $searchFrom; $i -le ($buf.Length - 2); $i++) {
            if ($buf[$i] -eq 0xFF -and $buf[$i + 1] -eq 0xC2) {
                $progIdx = $i
                break
            }
        }
        if ($progIdx -ge 0 -and ($progIdx + 9) -lt $buf.Length) {
            return ($buf[$progIdx + 9] -eq 4)
        }

        $start = $idx + 2
        if ($start -ge $buf.Length) { return $false }
    }
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
        IsEXESFX      = (Test-FoIsEXESFX -Path $InputFile)
        IsJPEGCMYK    = (Test-FoIsJPEGCMYK -Path $InputFile)
        IsPDFLayered  = (Test-FoIsPDFLayered -Path $InputFile)
    }
}
