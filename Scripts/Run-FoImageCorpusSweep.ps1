#Requires -Version 5.1
<#
.SYNOPSIS
  One-shot corpus sweep runner with optional tier bootstrap and summary output.

.DESCRIPTION
  Convenience wrapper around Get-ImageTestCorpus.ps1 and Invoke-FoImageCorpusSweep.ps1
  for scheduled/manual runs. Can ensure Tier B/C/D is downloaded, run the sweep in a
  child PowerShell process, and write a compact JSON summary next to the CSV output.
#>
[CmdletBinding()]
param(
    [ValidateSet('A', 'B', 'C', 'D')]
    [string]$Tier = 'B',
    [string]$ProfileName = 'LosslessDefault',
    [ValidateSet('Pixel', 'SSIM', 'SSIMOnly')]
    [string]$CompareMode,
    [string]$PluginPath,
    [string]$CorpusRoot,
    [int]$MaxFiles = 0,
    [switch]$SkipCompare,
    [switch]$AllowMissingDssim,
    [switch]$EnsureTier,
    [string]$OutputDirectory = (Join-Path (Get-Location) 'artifacts\corpus-sweep'),
    [string]$SummaryJsonPath
)

$ErrorActionPreference = 'Stop'

$sweepScript = Join-Path $PSScriptRoot 'Invoke-FoImageCorpusSweep.ps1'
$tierScript = Join-Path $PSScriptRoot 'Get-ImageTestCorpus.ps1'

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$csvPath = Join-Path $OutputDirectory ("corpus-sweep-tier{0}-{1}-{2}.csv" -f $Tier.ToLower(), $ProfileName, $stamp)

if ($Tier -ne 'A' -and $EnsureTier) {
    $tierArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tierScript, '-Tier', $Tier)
    if ($CorpusRoot) { $tierArgs += @('-Destination', $CorpusRoot) }
    $tierProc = Start-Process -FilePath 'powershell.exe' -ArgumentList $tierArgs -NoNewWindow -Wait -PassThru
    if ($tierProc.ExitCode -ne 0) {
        throw "Tier bootstrap failed with exit code $($tierProc.ExitCode)."
    }
}

$sweepArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', $sweepScript,
    '-Tier', $Tier,
    '-ProfileName', $ProfileName,
    '-OutputCsv', $csvPath
)
if ($CompareMode) { $sweepArgs += @('-CompareMode', $CompareMode) }
if ($PluginPath) { $sweepArgs += @('-PluginPath', $PluginPath) }
if ($CorpusRoot) { $sweepArgs += @('-CorpusRoot', $CorpusRoot) }
if ($MaxFiles -gt 0) { $sweepArgs += @('-MaxFiles', $MaxFiles) }
if ($SkipCompare) { $sweepArgs += '-SkipCompare' }
if ($AllowMissingDssim) { $sweepArgs += '-AllowMissingDssim' }

$sweepProc = Start-Process -FilePath 'powershell.exe' -ArgumentList $sweepArgs -NoNewWindow -Wait -PassThru
$exitCode = $sweepProc.ExitCode

$rows = @()
if (Test-Path -LiteralPath $csvPath) {
    $rows = @(Import-Csv -LiteralPath $csvPath)
}

$passed = @($rows | Where-Object { $_.Pass -eq 'True' }).Count
$failed = @($rows | Where-Object { $_.Pass -ne 'True' }).Count
$errors = @($rows | Where-Object { $_.Error }).Count

$summary = [PSCustomObject]@{
    Tier        = $Tier
    ProfileName = $ProfileName
    CompareMode = if ($CompareMode) { $CompareMode } else { '(profile default)' }
    CsvPath      = $csvPath
    RowCount     = $rows.Count
    Passed       = $passed
    Failed       = $failed
    Errors       = $errors
    ExitCode     = $exitCode
}

if (-not $SummaryJsonPath) {
    $SummaryJsonPath = Join-Path $OutputDirectory ("corpus-sweep-tier{0}-{1}-{2}.summary.json" -f $Tier.ToLower(), $ProfileName, $stamp)
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $SummaryJsonPath -Encoding UTF8

Write-Host ("Sweep summary: passed={0}, failed={1}, errors={2}" -f $passed, $failed, $errors)
Write-Host "CSV: $csvPath"
Write-Host "Summary: $SummaryJsonPath"

exit $exitCode
