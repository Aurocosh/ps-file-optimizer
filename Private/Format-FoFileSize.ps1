function Format-FoFileSize {
    [CmdletBinding()]
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
