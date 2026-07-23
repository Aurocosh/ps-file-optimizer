#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ModuleRoot,

    [Parameter(Mandatory)]
    [version]$Version
)

$ErrorActionPreference = 'Stop'

$notesPath = Join-Path (Join-Path $ModuleRoot 'ReleaseNotes') ('{0}.md' -f $Version)
if (-not (Test-Path -LiteralPath $notesPath)) {
    return $null
}

[PSCustomObject]@{
    Path    = (Resolve-Path -LiteralPath $notesPath).Path
    Content = (Get-Content -LiteralPath $notesPath -Raw).TrimEnd() + [Environment]::NewLine
}
