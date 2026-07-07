function Import-FoPsd1File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "PSD1 file not found: $Path"
    }

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return Import-PowerShellDataFile -Path $Path
    }

    $content = Get-Content -LiteralPath $Path -Raw
    return & ([scriptblock]::Create($content))
}
