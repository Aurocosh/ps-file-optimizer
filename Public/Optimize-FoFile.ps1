function Optimize-FoFile {
    <#
    .SYNOPSIS
    Optimizes one or more files using FileOptimizer plugin chains.

    .DESCRIPTION
    Resolves settings, selects pipeline groups per file extension, runs the plugin
    chain, and optionally records history. Supports -WhatIf for dry-run output.

    .PARAMETER Path
    File or directory paths to optimize. Directories are not expanded unless -Recurse is set.

    .PARAMETER ConfigPath
    Optional local JSON config file merged after global config.

    .PARAMETER ContinueOnError
    When optimizing multiple files, record per-file errors and continue instead of stopping the batch.

    .PARAMETER Level
    Optimization level (0–9). Default from config.

    .PARAMETER PluginSearchMode
    How to resolve plugin executables: PortableFirst, PathFirst, PortableOnly, or PathOnly.

    .PARAMETER PluginPath
    Portable plugin directory (Plugins64/Plugins32).

    .PARAMETER OutputMode
    TempMove, Replace, OptimizedSuffix, BackupSuffix, or BackupMove.

    .PARAMETER ShowProgress
    Show per-step progress during optimization.

    .PARAMETER Recurse
    When Path is a directory, include files in subdirectories.

    .PARAMETER MissingToolsPolicy
    How to handle required plugin tools that are not found: Error (default),
    SkipTool (skip those steps), or SkipFile (skip the whole file).

    .PARAMETER AcknowledgeOutdatedPlugins
    Persist acknowledgment of the current minimum plugin-bundle version and continue
    with a warning when the installed bundle is older than required.

    .EXAMPLE
    Optimize-FoFile -Path .\images\photo.png

    .EXAMPLE
    Optimize-FoFile -Path .\docs -Recurse -WhatIf

    .EXAMPLE
    .\Scripts\Optimize-File.ps1 .\images\*.png
    # CLI wrapper with the same parameters.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Optimize')]
    [OutputType([object[]])]
    param(
        [Parameter(ParameterSetName = 'Optimize', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'PSPath')]
        [string[]]$Path,
        [string]$ConfigPath,
        [ValidateRange(0, 9)]
        [nullable[int]]$Level,
        [ValidateSet('PortableFirst', 'PathFirst', 'PortableOnly', 'PathOnly')]
        [string]$PluginSearchMode,
        [string]$PluginPath,
        [ValidateRange(0, 3)]
        [nullable[int]]$LogLevel,
        [ValidateRange(0, 3)]
        [nullable[int]]$ReportLogLevel,
        [string]$ReportPath,
        [ValidateSet('Replace', 'OptimizedSuffix', 'BackupSuffix', 'BackupMove', 'TempMove')]
        [string]$OutputMode,
        [string]$BackupPath,
        [string]$BackupSuffix,
        [string]$OptimizedSuffix,
        [string]$TempBackupPath,
        [nullable[bool]]$HistoryEnabled,
        [string]$HistoryPath,
        [ValidateSet('Error', 'SkipTool', 'SkipFile')]
        [string]$MissingToolsPolicy,
        [nullable[bool]]$SkipMissingTools,
        [switch]$ShowProgress,
        [switch]$Recurse,
        [switch]$ContinueOnError,
        [switch]$AcknowledgeOutdatedPlugins
    )

    begin {
        $script:FoBatchResults = [System.Collections.Generic.List[object]]::new()
        $script:FoBatchSettings = $null
    }

    process {
        if (-not $Path) { return }

        if ($AcknowledgeOutdatedPlugins) {
            $min = Get-FoMinimumPluginBundleVersion
            $ackConfig = if ($ConfigPath) { $ConfigPath } else { $null }
            Set-FoAcknowledgedPluginBundleMinimum -MinimumVersion $min -ConfigPath $ackConfig
        }

        $settings = Merge-FoSettings -BoundParameters $PSBoundParameters
        if ($AcknowledgeOutdatedPlugins) {
            $settings.AcknowledgedPluginBundleMinimum = Get-FoMinimumPluginBundleVersion
        }
        $script:FoBatchSettings = $settings
        $targets = Get-FoTargetFiles -Path $Path -Recurse:$Recurse

        foreach ($file in $targets) {
            $gate = Test-FoFileGate -Path $file -Settings $settings
            if (-not $gate.Pass) {
                Write-FoLog -LogLevel $settings.LogLevel -RequiredLevel 1 -Message "Skipped $file ($($gate.Reason))"
                $script:FoBatchResults.Add([PSCustomObject]@{ Path = $file; Status = 'Skipped'; Reason = $gate.Reason })
                continue
            }

            if ((Get-Item -LiteralPath $file).Length -eq 0) {
                Write-FoLog -LogLevel $settings.LogLevel -RequiredLevel 1 -Message "Skipped $file (zero-byte file)"
                $script:FoBatchResults.Add([PSCustomObject]@{ Path = $file; Status = 'Skipped'; Reason = 'ZeroByte' })
                continue
            }

            $groups = Get-FoPipelineGroupsForFile -Path $file -Settings $settings
            if ($groups.Count -eq 0) {
                Write-FoLog -LogLevel $settings.LogLevel -RequiredLevel 1 -Message "Skipped $file (unsupported extension)"
                $script:FoBatchResults.Add([PSCustomObject]@{ Path = $file; Status = 'Skipped'; Reason = 'Unsupported' })
                continue
            }

            if ($PSCmdlet.ShouldProcess($file, 'Optimize file')) {
                try {
                    $result = Invoke-FoPluginChain -Path $file -Settings $settings -ShowProgress:$ShowProgress -Confirm:$false
                    if ($result.Status -eq 'Optimized') {
                        if ($settings.LogLevel -ge 1) {
                            Write-Host ('Optimized {0}: {1} -> {2} (-{3}%)' -f $file, (Format-FoFileSize $result.OriginalSize), (Format-FoFileSize $result.FinalSize), $result.PercentSaved)
                        }
                        if ($settings.HistoryEnabled) {
                            Add-FoHistoryEntry -Result $result -Settings $settings
                        }
                    }
                    elseif ($result.Status -eq 'Unchanged' -and $settings.LogLevel -ge 1) {
                        if ($result.Reason -eq 'MissingTools') {
                            $missing = @($result.Missing)
                            $hint = if ($missing.Count -gt 0) {
                                "missing tools: $($missing -join ', ')"
                            }
                            else {
                                'no plugin tools available'
                            }
                            Write-Host ("Unchanged {0}: {1} ({2}; check PluginPath or run Install-FoPlugins)" -f $file, (Format-FoFileSize $result.OriginalSize), $hint)
                        }
                        else {
                            Write-Host "Unchanged $file`: $(Format-FoFileSize $result.OriginalSize) (already optimal)"
                        }
                    }
                    $script:FoBatchResults.Add($result)
                }
                catch {
                    if ($ContinueOnError) {
                        Write-FoLog -LogLevel $settings.LogLevel -RequiredLevel 1 -Message "Error optimizing ${file}: $($_.Exception.Message)"
                    }
                    else {
                        Write-Error $_
                    }
                    $script:FoBatchResults.Add([PSCustomObject]@{ Path = $file; Status = 'Error'; Reason = $_.Exception.Message })
                    if (-not $ContinueOnError) { throw }
                }
            }
            elseif ($WhatIfPreference) {
                $result = Invoke-FoPluginChain -Path $file -Settings $settings -ShowProgress:$false -Confirm:$false
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
