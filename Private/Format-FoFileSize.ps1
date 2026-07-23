function Format-FoFileSize {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [long]$Bytes,
        [switch]$IncludeBytes
    )

    $abs = [math]::Abs($Bytes)
    $sign = if ($Bytes -lt 0) { '-' } else { '' }
    $ic = [System.Globalization.CultureInfo]::InvariantCulture

    $formatted = if ($abs -ge 1GB) {
        [string]::Format($ic, '{0:N2} GB', ($abs / 1GB))
    }
    elseif ($abs -ge 1MB) {
        [string]::Format($ic, '{0:N2} MB', ($abs / 1MB))
    }
    elseif ($abs -ge 1KB) {
        [string]::Format($ic, '{0:N1} KB', ($abs / 1KB))
    }
    else {
        [string]::Format($ic, '{0:N0} B', $abs)
    }

    if ($IncludeBytes) {
        return [string]::Format($ic, '{0}{1} ({2:N0} B)', $sign, $formatted, $Bytes)
    }
    return ($sign + $formatted)
}

function Format-FoProcessArgument {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) { return '""' }
    if ($Value.Length -eq 0) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    $backslashes = 0
    foreach ($ch in $Value.ToCharArray()) {
        if ($ch -eq '\') {
            $backslashes++
            continue
        }
        if ($ch -eq '"') {
            [void]$sb.Append('\', ($backslashes * 2 + 1))
            [void]$sb.Append('"')
            $backslashes = 0
            continue
        }
        if ($backslashes -gt 0) {
            [void]$sb.Append('\', $backslashes)
            $backslashes = 0
        }
        [void]$sb.Append($ch)
    }
    if ($backslashes -gt 0) {
        [void]$sb.Append('\', ($backslashes * 2))
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}
