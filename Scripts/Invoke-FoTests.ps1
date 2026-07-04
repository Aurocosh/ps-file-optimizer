[CmdletBinding()]
param(
    [string[]]$Tag,
    [string[]]$ExcludeTag,
    [string]$Path,
    [ValidateSet('Detailed', 'Normal', 'Minimal', 'None')]
    [string]$Output = 'Detailed'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$testsRoot = if ($Path) { $Path } else { Join-Path $repoRoot 'Tests' }
$supportModule = Join-Path $testsRoot 'FoTestSupport\FoTestSupport.psd1'

if (-not (Test-Path -LiteralPath $supportModule)) {
    throw "FoTestSupport module not found at '$supportModule'."
}

Import-Module $supportModule -Force
Write-FoTestPluginVersions -PluginPath (Get-FoTestPluginPath) -Verbose:$VerbosePreference

$config = New-PesterConfiguration
$config.Run.Path = $testsRoot
$config.Run.PassThru = $true
$config.Output.Verbosity = $Output

if ($Tag) {
    $config.Filter.Tag = $Tag
}
if ($ExcludeTag) {
    $config.Filter.ExcludeTag = $ExcludeTag
}

$result = Invoke-Pester -Configuration $config

if ($result.FailedCount -gt 0 -or $result.FailedBlocksCount -gt 0) {
    exit 1
}

exit 0
