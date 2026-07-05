function Invoke-FoPluginChain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [hashtable]$Settings,
        [switch]$WhatIf,
        [switch]$ShowProgress
    )

    $plan = Get-FoExecutionPlan -Path $Path -Settings $Settings
    $allMissing = @($plan.Plans | ForEach-Object { $_.Missing } | Select-Object -Unique)
    $allSteps = @($plan.Plans | ForEach-Object { $_.Steps })

    if ($WhatIf) {
        foreach ($p in $plan.Plans) {
            Write-Host ('WHATIF: Would optimize {0} via {1} ({2} steps) [OutputMode={3}]' -f $Path, $p.GroupName, $p.Steps.Count, $Settings.OutputMode)
            foreach ($step in $p.Steps) {
                Write-Host ('WHATIF:   {0}' -f $step.Name)
            }
        }
        if ($allMissing.Count -gt 0) {
            Write-Host ('WHATIF:   missing tools: {0}' -f ($allMissing -join ', '))
        }
        return [PSCustomObject]@{
            Path   = $Path
            Status = 'WhatIf'
            Steps  = $allSteps
            Missing = $allMissing
        }
    }

    if ($allMissing.Count -gt 0) {
        if ($Settings.SkipMissingTools) {
            Write-Warning "Skipping '$Path' - missing tools: $($allMissing -join ', ')."
            return [PSCustomObject]@{
                Path       = $Path
                Status     = 'Skipped'
                Reason     = 'MissingTools'
                Missing    = $allMissing
                BytesSaved = 0
                Steps      = @()
            }
        }

        if ($Settings.LogLevel -ge 2) {
            Write-Host "Missing tools for '$Path' (continuing like FileOptimizer): $($allMissing -join ', ')"
        }
    }

    $workFile = Join-Path ([System.IO.Path]::GetTempPath()) ('FileOptimizer_work_{0}_{1}' -f (Get-Random -Max 99999), [System.IO.Path]::GetFileName($Path))
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
                        SizeBefore = $result.SizeBefore
                        SizeAfter  = $result.SizeAfter
                        Accepted   = $result.Accepted
                        DurationMs = $result.DurationMs
                    }
                    if ($Settings.LogLevel -ge 2 -and $result.Accepted) {
                        $pct = if ($result.SizeBefore -gt 0) { [math]::Round((1 - $result.SizeAfter / $result.SizeBefore) * 100, 1) } else { 0 }
                        Write-Host ('  {0}: {1} -> {2} (-{3}%)' -f $step.Name, (Format-FoFileSize $result.SizeBefore), (Format-FoFileSize $result.SizeAfter), $pct)
                    }
                }
            }
        }

        $finalSize = (Get-Item -LiteralPath $workFile).Length
        $sw.Stop()

        if ($finalSize -ge $originalSize) {
            return [PSCustomObject]@{
                Path         = $Path
                Status       = 'Unchanged'
                Reason       = $null
                OriginalSize = $originalSize
                FinalSize    = $originalSize
                BytesSaved   = 0
                PercentSaved = 0
                OutputPath   = $Path
                OriginalPath = $Path
                BackupPath   = $null
                Steps        = $stepLog
                DurationMs   = $sw.ElapsedMilliseconds
            }
        }

        $outputResult = Invoke-FoOutputMode -SourceFile $workFile -TargetPath $Path -Settings $Settings
        return [PSCustomObject]@{
            Path         = $Path
            Status       = 'Optimized'
            Reason       = $null
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
        }
    }
    finally {
        if (Test-Path -LiteralPath $workFile) { Remove-Item -LiteralPath $workFile -Force -ErrorAction SilentlyContinue }
        Write-Progress -Activity 'Optimizing' -Completed
    }
}
