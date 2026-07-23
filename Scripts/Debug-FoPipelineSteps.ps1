#Requires -Version 5.1
<#
.SYNOPSIS
  Run an image pipeline step-by-step and compare output after each step to find corruption.

.DESCRIPTION
  Mirrors Invoke-FoPluginChain execution but compares the working file against an untouched
  copy of the input after every plugin step. Reports the first step where visual compare fails.

  Uses the same compare stack as image integration tests (Compare-FoImage, JPEG SSIM fallback,
  GIF/APNG frame compare, ICO largest-icon compare).

.PARAMETER Path
  Image file to optimize.

.PARAMETER ProfileName
  Settings profile from Tests/ImageTestProfiles.psd1 (default LosslessDefault).

.PARAMETER CompareMode
  Pixel, SSIM, or SSIMOnly. Defaults to the profile CompareMode when omitted.

.PARAMETER PluginPath
  Plugin directory. Defaults to FO_TEST_PLUGIN_PATH or Get-FoDefaultPluginPath.

.PARAMETER WorkDirectory
  Folder for before copy, per-step snapshots, and failure diffs.

.PARAMETER AllowMissingDssim
  Allow PNG pixel compare to fall back to ImageMagick AE when dssim is absent.

.PARAMETER ContinueOnFailure
  Run all steps even after the first compare failure (default stops at first failure).

.EXAMPLE
  .\Scripts\Debug-FoPipelineSteps.ps1 .\Tests\Fixtures\Images\pngsuite\basn2c08.png

.EXAMPLE
  .\Scripts\Debug-FoPipelineSteps.ps1 .\photo.jpg -ProfileName LossyHighQuality -CompareMode SSIMOnly
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [Alias('FullName')]
    [string]$Path,
    [string]$ProfileName = 'LosslessDefault',
    [ValidateSet('Pixel', 'SSIM', 'SSIMOnly')]
    [string]$CompareMode,
    [string]$PluginPath,
    [string]$WorkDirectory,
    [switch]$AllowMissingDssim,
    [switch]$ContinueOnFailure
)

$ErrorActionPreference = 'Stop'

$moduleRoot = Split-Path -Parent $PSScriptRoot
$script:FoModuleRoot = $moduleRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force
Import-Module (Join-Path $moduleRoot 'Tests\FoTestSupport\FoTestSupport.psd1') -Force

. (Join-Path $moduleRoot 'Public\Resolve-FoPluginExecutable.ps1')
. (Join-Path $moduleRoot 'Private\Handlers\Invoke-FoNativeHandlers.ps1')
. (Join-Path $moduleRoot 'Private\Get-FoStepRequiredExecutables.ps1')
. (Join-Path $moduleRoot 'Private\Invoke-FoPlugin.ps1')
. (Join-Path $moduleRoot 'Private\Get-FoLevelFlags.ps1')
. (Join-Path $moduleRoot 'Private\Get-ExtensionByContent.ps1')
. (Join-Path $moduleRoot 'Private\Test-FoFileGate.ps1')
. (Join-Path $moduleRoot 'Pipelines\_Helpers.ps1')
Get-ChildItem -Path (Join-Path $moduleRoot 'Pipelines\*.ps1') -Exclude '_Helpers.ps1' | ForEach-Object { . $_.FullName }
. (Join-Path $moduleRoot 'Public\Get-FoPipeline.ps1')

function Invoke-FoDebugStepVisualCompare {
    param(
        [Parameter(Mandatory)][string]$Before,
        [Parameter(Mandatory)][string]$After,
        [Parameter(Mandatory)][string]$CompareMode,
        [Parameter(Mandatory)][string]$PluginPath,
        [string]$DiffOutputPath,
        [double]$SSIMDissimilarityMaximum = -1,
        [switch]$AllowMissingDssim,
        [string]$WorkDirectory
    )

    $ext = [System.IO.Path]::GetExtension($After)
    $decisions = Get-FoImageTestDecisions

    if ($ext -match '(?i)^\.gif$') {
        $beforeFrames = Get-FoGifFrameCount -Path $Before -PluginPath $PluginPath
        $afterFrames = Get-FoGifFrameCount -Path $After -PluginPath $PluginPath
        if ($beforeFrames -gt 1 -or $afterFrames -gt 1) {
            $frameDir = Join-Path $WorkDirectory 'frames'
            $frameCompare = Compare-FoGifFrames -Before $Before -After $After -PluginPath $PluginPath `
                -WorkDirectory $frameDir -DiffOutputPath $DiffOutputPath
            return [PSCustomObject]@{
                Pass         = $frameCompare.Pass
                CompareTool  = 'GifFrames'
                MetricValue  = if ($frameCompare.FrameResults) {
                    ($frameCompare.FrameResults | Measure-Object -Property MetricValue -Maximum).Maximum
                } else { $null }
                CompareMode  = $CompareMode
                Detail       = $frameCompare
            }
        }
    }

    if ($ext -match '(?i)^\.ico$') {
        $icoCompare = Compare-FoIcoLargest -Before $Before -After $After -PluginPath $PluginPath `
            -WorkDirectory (Join-Path $WorkDirectory 'ico') -DiffOutputPath $DiffOutputPath
        return [PSCustomObject]@{
            Pass         = $icoCompare.Pass
            CompareTool  = 'IcoLargest'
            MetricValue  = $icoCompare.MetricValue
            CompareMode  = $CompareMode
            Detail       = $icoCompare
        }
    }

    if ($ext -match '(?i)^\.png$') {
        $beforeApng = 1
        $afterApng = 1
        try { $beforeApng = Get-FoApngFrameCount -Path $Before -PluginPath $PluginPath -WorkDirectory (Join-Path $WorkDirectory 'apng-probe-before') } catch { Write-Debug $_.Exception.Message }
        try { $afterApng = Get-FoApngFrameCount -Path $After -PluginPath $PluginPath -WorkDirectory (Join-Path $WorkDirectory 'apng-probe-after') } catch { Write-Debug $_.Exception.Message }
        if (($beforeApng -gt 1) -or ($afterApng -gt 1)) {
            $apngCompare = Compare-FoApngFrames -Before $Before -After $After -PluginPath $PluginPath `
                -WorkDirectory (Join-Path $WorkDirectory 'apng') -DiffOutputPath $DiffOutputPath
            return [PSCustomObject]@{
                Pass         = $apngCompare.Pass
                CompareTool  = 'ApngFrames'
                MetricValue  = if ($apngCompare.FrameResults) {
                    ($apngCompare.FrameResults | Measure-Object -Property MetricValue -Maximum).Maximum
                } else { $null }
                CompareMode  = $CompareMode
                Detail       = $apngCompare
            }
        }
    }

    $modeEffective = if ($CompareMode -eq 'SSIMOnly') { 'SSIM' } else { $CompareMode }
    $compareParams = @{
        Before     = $Before
        After      = $After
        Mode       = $modeEffective
        PluginPath = $PluginPath
    }
    if ($DiffOutputPath) { $compareParams['DiffOutputPath'] = $DiffOutputPath }
    if ($modeEffective -eq 'SSIM' -and $SSIMDissimilarityMaximum -ge 0) {
        $compareParams['SSIMDissimilarityMaximum'] = $SSIMDissimilarityMaximum
    }
    if ($modeEffective -eq 'Pixel') {
        $compareParams['PngDssimDissimilarityMaximum'] = $decisions.PngDssimDissimilarityMaximum
    }
    if ($AllowMissingDssim) { $compareParams['AllowMissingDssim'] = $true }

    $compare = Compare-FoImage @compareParams

    if ($CompareMode -eq 'Pixel' -and -not $compare.Pass -and $ext -match '(?i)^\.jpe?g$') {
        $jpegCompare = Test-FoJpegImageCompare -Before $Before -After $After -PluginPath $PluginPath `
            -SSIMDissimilarityMaximum $SSIMDissimilarityMaximum -DiffOutputPath $DiffOutputPath `
            -AllowMissingDssim:$AllowMissingDssim
        $compare = $jpegCompare.Compare
        $modeEffective = $jpegCompare.CompareMode
    }

    return [PSCustomObject]@{
        Pass         = $compare.Pass
        CompareTool  = $compare.CompareTool
        MetricValue  = $compare.MetricValue
        CompareMode  = $modeEffective
        Detail       = $compare
    }
}

function Debug-FoPipelineSteps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$ProfileName = 'LosslessDefault',
        [ValidateSet('Pixel', 'SSIM', 'SSIMOnly')]
        [string]$CompareMode,
        [string]$PluginPath,
        [string]$WorkDirectory,
        [switch]$AllowMissingDssim,
        [switch]$ContinueOnFailure
    )

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "File not found: $Path"
    }

    $settings = Get-FoImageTestProfile -Name $ProfileName -PluginPath $PluginPath
    if ($settings.LogLevel -lt 2) { $settings['LogLevel'] = 2 }

    $effectiveCompareMode = if ($PSBoundParameters.ContainsKey('CompareMode')) {
        $CompareMode
    }
    else {
        Get-FoImageTestProfileCompareMode -Name $ProfileName
    }

    $ssimThreshold = -1
    if ($effectiveCompareMode -in @('SSIM', 'SSIMOnly')) {
        $ssimThreshold = Get-FoImageTestLossyThreshold -ProfileName $ProfileName `
            -ImagePath $resolvedPath -PluginPath $settings.PluginPath
    }

    $workRoot = if ($WorkDirectory) {
        [System.IO.Path]::GetFullPath($WorkDirectory)
    }
    else {
        Join-Path $env:TEMP ("FoPipelineDebug_{0}" -f (Get-Random))
    }
    if (-not (Test-Path -LiteralPath $workRoot)) {
        New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
    }

    $fileName = [System.IO.Path]::GetFileName($resolvedPath)
    $beforePath = Join-Path $workRoot "before_$fileName"
    $workFile = Join-Path $workRoot "work_$fileName"
    Copy-Item -LiteralPath $resolvedPath -Destination $beforePath -Force
    Copy-Item -LiteralPath $resolvedPath -Destination $workFile -Force

    $plan = Get-FoExecutionPlan -Path $workFile -Settings $settings
    if ($plan.Plans.Count -eq 0) {
        throw "No pipeline groups for '$resolvedPath'."
    }

    Write-Host "Debugging $($plan.Plans.GroupName -join ', ') ($($plan.Plans.Steps.Count) steps) [CompareMode=$effectiveCompareMode]" -ForegroundColor Cyan
    Write-Host "Work directory: $workRoot"

    $stepResults = [System.Collections.Generic.List[object]]::new()
    $firstFailure = $null
    $stepIndex = 0

    foreach ($p in $plan.Plans) {
        foreach ($step in $p.Steps) {
            $stepIndex++
            $stepLabel = $step.Name
            $pluginResult = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $settings `
                -PluginPath $settings.PluginPath -SearchMode $settings.PluginSearchMode

            $snapshot = Join-Path $workRoot ("step_{0:D2}_{1}" -f $stepIndex, ($stepLabel -replace '[^\w\-]', '_'))
            Copy-Item -LiteralPath $workFile -Destination $snapshot -Force

            $diffPath = Join-Path $workRoot ("diff_{0:D2}.png" -f $stepIndex)
            $compare = Invoke-FoDebugStepVisualCompare -Before $beforePath -After $workFile `
                -CompareMode $effectiveCompareMode -PluginPath $settings.PluginPath `
                -DiffOutputPath $diffPath -SSIMDissimilarityMaximum $ssimThreshold `
                -AllowMissingDssim:$AllowMissingDssim -WorkDirectory $workRoot

            $entry = [PSCustomObject]@{
                Index        = $stepIndex
                Step         = $stepLabel
                Group        = $p.GroupName
                Accepted     = $pluginResult.Accepted
                Skipped      = $pluginResult.Skipped
                SizeBefore   = $pluginResult.SizeBefore
                SizeAfter    = $pluginResult.SizeAfter
                ComparePass  = $compare.Pass
                CompareTool  = $compare.CompareTool
                MetricValue  = $compare.MetricValue
                SnapshotPath = $snapshot
                DiffPath     = if ($compare.Pass) { $null } else { $diffPath }
            }
            $stepResults.Add($entry)

            $statusColor = if ($compare.Pass) { 'Green' } else { 'Red' }
            $metricText = if ($null -ne $compare.MetricValue) { " metric=$($compare.MetricValue)" } else { '' }
            Write-Host ("  [{0}] {1}: compare={2}{3} size {4} -> {5}" -f $stepIndex, $stepLabel, $compare.Pass, $metricText,
                (Format-FoFileSize $pluginResult.SizeBefore), (Format-FoFileSize $pluginResult.SizeAfter)) -ForegroundColor $statusColor

            if (-not $compare.Pass -and -not $firstFailure) {
                $firstFailure = $entry
                if (-not $ContinueOnFailure) {
                    Write-Warning "First failing step: $stepLabel (snapshot: $snapshot, diff: $diffPath)"
                    break
                }
            }
        }

        if ($firstFailure -and -not $ContinueOnFailure) { break }
    }

    $summary = [PSCustomObject]@{
        Path           = $resolvedPath
        ProfileName    = $ProfileName
        CompareMode    = $effectiveCompareMode
        WorkDirectory  = $workRoot
        BeforePath     = $beforePath
        FinalPath      = $workFile
        StepResults    = @($stepResults)
        FirstFailure   = $firstFailure
        AllPassed      = ($null -eq $firstFailure)
        Groups         = @($plan.Plans.GroupName)
    }

    if ($summary.AllPassed) {
        Write-Host 'All steps passed visual compare.' -ForegroundColor Green
    }
    else {
        Write-Host ("First failure at step {0}: {1}" -f $firstFailure.Index, $firstFailure.Step) -ForegroundColor Yellow
    }

    return $summary
}

if (-not (Test-FoPluginsAvailable)) {
    throw 'Plugin binaries required. Set FO_TEST_PLUGIN_PATH or run Install-Plugins.ps1.'
}

Debug-FoPipelineSteps @PSBoundParameters
