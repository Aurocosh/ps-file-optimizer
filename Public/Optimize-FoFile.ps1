function Get-FoTargetFiles {
    param(
        [string[]]$Path,
        [switch]$Recurse
    )

    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($p in $Path) {
        if (-not $p) { continue }
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
        if (Test-Path -LiteralPath $resolved -PathType Container) {
            $params = @{ LiteralPath = $resolved; File = $true; ErrorAction = 'SilentlyContinue' }
            if ($Recurse) { $params.Recurse = $true }
            Get-ChildItem @params | ForEach-Object { $files.Add($_.FullName) }
        }
        elseif (Test-Path -LiteralPath $resolved -PathType Leaf) {
            $files.Add($resolved)
        }
        else {
            Write-Warning "Path not found: $p"
        }
    }
    return @($files | Select-Object -Unique)
}

function Optimize-FoFile {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Optimize')]
    param(
        [Parameter(ParameterSetName = 'Optimize', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'PSPath')]
        [string[]]$Path,
        [string]$ConfigPath,
        [nullable[int]]$Level,
        [string]$PluginSearchMode,
        [string]$PluginPath,
        [nullable[int]]$LogLevel,
        [nullable[int]]$ReportLogLevel,
        [string]$ReportPath,
        [string]$OutputMode,
        [string]$BackupPath,
        [string]$BackupSuffix,
        [string]$OptimizedSuffix,
        [string]$TempBackupPath,
        [nullable[bool]]$SkipMissingTools,
        [nullable[bool]]$HistoryEnabled,
        [string]$HistoryPath,
        [switch]$ShowProgress,
        [switch]$Recurse
    )

    begin {
        $script:FoBatchResults = [System.Collections.Generic.List[object]]::new()
        $script:FoBatchSettings = $null
    }

    process {
        if (-not $Path) { return }
        $settings = Merge-FoSettings -BoundParameters $PSBoundParameters
        $script:FoBatchSettings = $settings
        $targets = Get-FoTargetFiles -Path $Path -Recurse:$Recurse

        foreach ($file in $targets) {
            $gate = Test-FoFileGate -Path $file -Settings $settings
            if (-not $gate.Pass) {
                Write-FoLog -LogLevel $settings.LogLevel -RequiredLevel 1 -Message "Skipped $file ($($gate.Reason))"
                $script:FoBatchResults.Add([PSCustomObject]@{ Path = $file; Status = 'Skipped'; Reason = $gate.Reason })
                continue
            }

            $groups = Get-FoPipelineGroupsForFile -Path $file
            if ($groups.Count -eq 0) {
                Write-FoLog -LogLevel $settings.LogLevel -RequiredLevel 1 -Message "Skipped $file (unsupported extension)"
                $script:FoBatchResults.Add([PSCustomObject]@{ Path = $file; Status = 'Skipped'; Reason = 'Unsupported' })
                continue
            }

            if ($PSCmdlet.ShouldProcess($file, 'Optimize file')) {
                try {
                    $result = Invoke-FoPluginChain -Path $file -Settings $settings -ShowProgress:$ShowProgress
                    if ($result.Status -eq 'Optimized') {
                        if ($settings.LogLevel -ge 1) {
                            Write-Host ('Optimized {0}: {1} -> {2} (-{3}%)' -f $file, (Format-FoFileSize $result.OriginalSize), (Format-FoFileSize $result.FinalSize), $result.PercentSaved)
                        }
                        if ($settings.HistoryEnabled) {
                            Add-FoHistoryEntry -Result $result -Settings $settings
                        }
                    }
                    elseif ($result.Status -eq 'Unchanged' -and $settings.LogLevel -ge 1) {
                        Write-Host "Unchanged $file`: $(Format-FoFileSize $result.OriginalSize) (already optimal)"
                    }
                    $script:FoBatchResults.Add($result)
                }
                catch {
                    Write-Error $_
                    $script:FoBatchResults.Add([PSCustomObject]@{ Path = $file; Status = 'Error'; Reason = $_.Exception.Message })
                    if (-not $settings.SkipMissingTools) { throw }
                }
            }
            else {
                $result = Invoke-FoPluginChain -Path $file -Settings $settings -WhatIf -ShowProgress:$false
                $script:FoBatchResults.Add($result)
            }
        }
    }

    end {
        if ($script:FoBatchSettings -and $script:FoBatchSettings.ReportPath -and $script:FoBatchResults.Count -gt 0) {
            Write-FoReport -Results @($script:FoBatchResults) -Settings $script:FoBatchSettings -ReportPath $script:FoBatchSettings.ReportPath
        }
        return @($script:FoBatchResults)
    }
}
