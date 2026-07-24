function Invoke-FoPluginChain {
    <#
    .SYNOPSIS
    Runs the full plugin chain for a single file.

    .DESCRIPTION
    Builds an execution plan, runs each active step in order, applies output mode
    when the result is smaller, and returns a result object with status and sizes.

    MissingToolsPolicy controls required-tool gaps:
    Error (default) fails the file; SkipTool continues other steps; SkipFile skips
    the whole file. A missing portable plugin bundle (no Install-FoPlugins tree)
    always fails unless PluginSearchMode is PathOnly.

    .PARAMETER Path
    File to optimize.

    .PARAMETER Settings
    Merged settings from Get-FoConfig.

    .PARAMETER ShowProgress
    Show per-step progress.

    .EXAMPLE
    Invoke-FoPluginChain -Path .\photo.png -Settings (Get-FoConfig) -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [hashtable]$Settings,
        [switch]$ShowProgress
    )

    $plan = Get-FoExecutionPlan -Path $Path -Settings $Settings
    $groupNames = @($plan.Plans | ForEach-Object { $_.GroupName })
    $allMissing = @($plan.Plans | ForEach-Object { $_.Missing } | Select-Object -Unique)
    $allSteps = @($plan.Plans | ForEach-Object { $_.Steps })
    $optimizeAction = 'Optimize via {0}' -f ($groupNames -join ', ')
    $reportVerbosity = Get-FoReportVerbosity -Settings $Settings
    $verboseHost = $reportVerbosity -eq 'Verbose'

    if (-not $PSCmdlet.ShouldProcess($Path, $optimizeAction)) {
        # Detailed WhatIf step lists only in Verbose; Compact/Standard summarize at end of Optimize-FoFile.
        if ($verboseHost) {
            foreach ($p in $plan.Plans) {
                Write-Host ('WHATIF: Would optimize {0} via {1} ({2} steps) [OutputMode={3}]' -f $Path, $p.GroupName, $p.Steps.Count, $Settings.OutputMode)
                foreach ($step in $p.Steps) {
                    Write-Host ('WHATIF:   {0}' -f $step.Name)
                }
            }
            if ($allMissing.Count -gt 0) {
                Write-Host ('WHATIF:   missing tools: {0}' -f ($allMissing -join ', '))
            }
        }
        return (Set-FoOptimizeResultDisplay -Result ([PSCustomObject]@{
            Path    = $Path
            Status  = 'WhatIf'
            Groups  = $groupNames
            Steps   = $allSteps
            Missing = $allMissing
        }))
    }

    Assert-FoPluginBundleVersionForOptimize -Settings $Settings

    $missingPolicy = [string]$Settings.MissingToolsPolicy
    if ([string]::IsNullOrWhiteSpace($missingPolicy)) { $missingPolicy = 'Error' }

    if ($allMissing.Count -gt 0) {
        switch ($missingPolicy) {
            'SkipFile' {
                Write-Warning "Skipping '$Path' - missing tools: $($allMissing -join ', ')."
                return (Set-FoOptimizeResultDisplay -Result ([PSCustomObject]@{
                    Path       = $Path
                    Status     = 'Skipped'
                    Reason     = 'MissingTools'
                    Groups     = $groupNames
                    Missing    = $allMissing
                    BytesSaved = 0
                    Steps      = @()
                }))
            }
            'SkipTool' {
                if ($verboseHost -and $Settings.LogLevel -ge 2) {
                    Write-Host "Missing tools for '$Path' (skipping those steps): $($allMissing -join ', ')"
                }
            }
            default {
                throw ("Required plugin tool(s) missing for '{0}': {1}. Run Install-FoPlugins to install the bundle, or set MissingToolsPolicy to SkipTool (skip individual steps) or SkipFile (skip this file)." -f $Path, ($allMissing -join ', '))
            }
        }
    }

    if ($verboseHost -and $Settings.LogLevel -ge 2) {
        Write-Host ('Optimizing {0} via {1}' -f $Path, ($groupNames -join ', '))
    }

    $workFile = Join-Path ([System.IO.Path]::GetTempPath()) ('FileOptimizer_work_{0}_{1}' -f ([guid]::NewGuid().ToString('N')), [System.IO.Path]::GetFileName($Path))
    Copy-Item -LiteralPath $Path -Destination $workFile -Force
    $originalSize = (Get-Item -LiteralPath $Path).Length
    $stepLog = @()
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        foreach ($p in $plan.Plans) {
            foreach ($step in $p.Steps) {
                if ($ShowProgress) {
                    Write-Progress -Activity 'Optimizing' -Status $step.Name -CurrentOperation $Path
                }
                $result = Invoke-FoPlugin -Step $step -InputFile $workFile -Settings $Settings -PluginPath $Settings.PluginPath -SearchMode $Settings.PluginSearchMode
                if (-not $result.Skipped) {
                    $stepLog += [PSCustomObject]@{
                        Step       = $step.Name
                        Group      = $p.GroupName
                        ExitCode   = $result.ExitCode
                        Reason     = $result.Reason
                        SizeBefore = $result.SizeBefore
                        SizeAfter  = $result.SizeAfter
                        Accepted   = $result.Accepted
                        DurationMs = $result.DurationMs
                    }
                    if ($verboseHost -and $Settings.LogLevel -ge 2 -and $result.Accepted) {
                        $unit = Get-FoSizeDisplayUnit -Settings $Settings
                        Write-Host ('  {0}: {1}' -f $step.Name, (Format-FoSizeChange -OriginalSize $result.SizeBefore -FinalSize $result.SizeAfter -Unit $unit))
                    }
                }
            }
        }

        $finalSize = (Get-Item -LiteralPath $workFile).Length
        $sw.Stop()

        if ($finalSize -ge $originalSize) {
            $unchangedReason = $null
            if ($stepLog.Count -eq 0 -and $allMissing.Count -gt 0) {
                $unchangedReason = 'MissingTools'
            }
            return (Set-FoOptimizeResultDisplay -Result ([PSCustomObject]@{
                Path         = $Path
                Status       = 'Unchanged'
                Reason       = $unchangedReason
                Groups       = $groupNames
                OriginalSize = $originalSize
                FinalSize    = $originalSize
                BytesSaved   = 0
                PercentSaved = 0
                OutputPath   = $Path
                OriginalPath = $Path
                BackupPath   = $null
                Missing      = $allMissing
                Steps        = $stepLog
                DurationMs   = $sw.ElapsedMilliseconds
            }))
        }

        $outputResult = Invoke-FoOutputMode -SourceFile $workFile -TargetPath $Path -Settings $Settings
        return (Set-FoOptimizeResultDisplay -Result ([PSCustomObject]@{
            Path         = $Path
            Status       = 'Optimized'
            Reason       = $null
            Groups       = $groupNames
            OriginalSize = $originalSize
            FinalSize    = $finalSize
            BytesSaved   = ($originalSize - $finalSize)
            PercentSaved = if ($originalSize -gt 0) { [math]::Round(($originalSize - $finalSize) / $originalSize * 100, 1) } else { 0 }
            OutputPath   = $outputResult.OptimizedPath
            OriginalPath = $outputResult.OriginalPath
            BackupPath   = $outputResult.BackupPath
            OutputMode   = $Settings.OutputMode
            Steps        = $stepLog
            DurationMs   = $sw.ElapsedMilliseconds
        }))
    }
    finally {
        if (Test-Path -LiteralPath $workFile) { Remove-Item -LiteralPath $workFile -Force -ErrorAction SilentlyContinue }
        Write-Progress -Activity 'Optimizing' -Completed
    }
}
