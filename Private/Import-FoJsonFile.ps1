function ConvertTo-FoHashtable {
    param($InputObject)

    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [hashtable]) { return $InputObject }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-FoHashtable -InputObject $InputObject[$key]
        }
        return $result
    }
    if ($InputObject -is [pscustomobject]) {
        $result = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $result[$prop.Name] = ConvertTo-FoHashtable -InputObject $prop.Value
        }
        return $result
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return @($InputObject | ForEach-Object { ConvertTo-FoHashtable -InputObject $_ })
    }

    return $InputObject
}

function Import-FoJsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    $raw = [System.IO.File]::ReadAllText($Path)
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return ConvertFrom-Json -InputObject $raw -AsHashtable -Depth 100
    }

    return ConvertTo-FoHashtable -InputObject (ConvertFrom-Json -InputObject $raw)
}

function Save-FoJsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        $Data,
        [int]$Depth = 10
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $json = $Data | ConvertTo-Json -Depth $Depth
    $tmp = "$Path.tmp"
    Set-Content -LiteralPath $tmp -Value $json -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}
