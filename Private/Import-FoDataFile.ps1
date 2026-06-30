function Import-FoDataFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Data file not found: $Path"
    }

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return Import-PowerShellDataFile -Path $Path
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $sb = [scriptblock]::Create($content)
    return & $sb
}
