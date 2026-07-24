function Format-FoFileSize {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [long]$Bytes,
        [ValidateSet('Auto', 'Bytes', 'KB', 'MB', 'GB')]
        [string]$Unit = 'Auto',
        [switch]$IncludeBytes
    )

    $abs = [math]::Abs($Bytes)
    $sign = if ($Bytes -lt 0) { '-' } else { '' }
    $ic = [System.Globalization.CultureInfo]::InvariantCulture

    $resolvedUnit = $Unit
    if ($resolvedUnit -eq 'Auto') {
        if ($abs -ge 1GB) { $resolvedUnit = 'GB' }
        elseif ($abs -ge 1MB) { $resolvedUnit = 'MB' }
        elseif ($abs -ge 1KB) { $resolvedUnit = 'KB' }
        else { $resolvedUnit = 'Bytes' }
    }

    $formatted = switch ($resolvedUnit) {
        'GB' { [string]::Format($ic, '{0:N2} GB', ($abs / 1GB)) }
        'MB' { [string]::Format($ic, '{0:N2} MB', ($abs / 1MB)) }
        'KB' { [string]::Format($ic, '{0:N1} KB', ($abs / 1KB)) }
        default { [string]::Format($ic, '{0:N0} B', $abs) }
    }

    if ($IncludeBytes -and $resolvedUnit -ne 'Bytes') {
        return [string]::Format($ic, '{0}{1} ({2:N0} B)', $sign, $formatted, $Bytes)
    }
    return ($sign + $formatted)
}

function Format-FoSizeChange {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [long]$OriginalSize,
        [Parameter(Mandatory)]
        [long]$FinalSize,
        [ValidateSet('Auto', 'Bytes', 'KB', 'MB', 'GB')]
        [string]$Unit = 'Auto'
    )

    $pct = if ($OriginalSize -gt 0) {
        [math]::Round((1 - $FinalSize / $OriginalSize) * 100, 1)
    }
    else { 0 }

    return '{0} -> {1} (-{2}%)' -f `
        (Format-FoFileSize -Bytes $OriginalSize -Unit $Unit), `
        (Format-FoFileSize -Bytes $FinalSize -Unit $Unit), `
        $pct
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
