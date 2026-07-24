function Optimize-FoFile {
    <#
    .SYNOPSIS
    Optimizes one or more files using FileOptimizer plugin chains.

    .DESCRIPTION
    Resolves settings, selects pipeline groups per file extension, runs the plugin
    chain, and optionally records history. Supports -WhatIf for dry-run output.
    Each invocation is one history batch when HistoryEnabled is true.

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

    .PARAMETER ReportVerbosity
    Compact, Standard (default), or Verbose console/report layout.

    .PARAMETER SizeDisplayUnit
    Auto (default pretty), Bytes, KB, MB, or GB for size display.

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
        [ValidateSet('Compact', 'Standard', 'Verbose')]
        [string]$ReportVerbosity,
        [ValidateSet('Auto', 'Bytes', 'KB', 'MB', 'GB')]
        [string]$SizeDisplayUnit,
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
        $script:FoBatchId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 8))
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
        $verbosity = Get-FoReportVerbosity -Settings $settings

        foreach ($file in $targets) {
            $gate = Test-FoFileGate -Path $file -Settings $settings
            if (-not $gate.Pass) {
                Write-FoLog -LogLevel $settings.LogLevel -RequiredLevel 1 -Message "Skipped $file ($($gate.Reason))"
                $skipped = [PSCustomObject]@{ Path = $file; Status = 'Skipped'; Reason = $gate.Reason }
                $script:FoBatchResults.Add($skipped)
                if ($verbosity -eq 'Verbose' -and $settings.LogLevel -ge 1) {
                    Write-FoOptimizeResultVerboseLine -Result $skipped -Unit (Get-FoSizeDisplayUnit -Settings $settings)
                }
                continue
            }

            if ((Get-Item -LiteralPath $file).Length -eq 0) {
                Write-FoLog -LogLevel $settings.LogLevel -RequiredLevel 1 -Message "Skipped $file (zero-byte file)"
                $skipped = [PSCustomObject]@{ Path = $file; Status = 'Skipped'; Reason = 'ZeroByte' }
                $script:FoBatchResults.Add($skipped)
                if ($verbosity -eq 'Verbose' -and $settings.LogLevel -ge 1) {
                    Write-FoOptimizeResultVerboseLine -Result $skipped -Unit (Get-FoSizeDisplayUnit -Settings $settings)
                }
                continue
            }

            $groups = Get-FoPipelineGroupsForFile -Path $file -Settings $settings
            if ($groups.Count -eq 0) {
                Write-FoLog -LogLevel $settings.LogLevel -RequiredLevel 1 -Message "Skipped $file (unsupported extension)"
                $skipped = [PSCustomObject]@{ Path = $file; Status = 'Skipped'; Reason = 'Unsupported' }
                $script:FoBatchResults.Add($skipped)
                if ($verbosity -eq 'Verbose' -and $settings.LogLevel -ge 1) {
                    Write-FoOptimizeResultVerboseLine -Result $skipped -Unit (Get-FoSizeDisplayUnit -Settings $settings)
                }
                continue
            }

            if ($PSCmdlet.ShouldProcess($file, 'Optimize file')) {
                try {
                    $result = Invoke-FoPluginChain -Path $file -Settings $settings -ShowProgress:$ShowProgress -Confirm:$false
                    if ($result.Status -eq 'Optimized') {
                        if ($settings.HistoryEnabled) {
                            Add-FoHistoryEntry -Result $result -Settings $settings -BatchId $script:FoBatchId
                        }
                    }
                    if ($verbosity -eq 'Verbose' -and $settings.LogLevel -ge 1) {
                        Write-FoOptimizeResultVerboseLine -Result $result -Unit (Get-FoSizeDisplayUnit -Settings $settings)
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
                    $err = [PSCustomObject]@{ Path = $file; Status = 'Error'; Reason = $_.Exception.Message }
                    $script:FoBatchResults.Add($err)
                    if ($verbosity -eq 'Verbose' -and $settings.LogLevel -ge 1) {
                        Write-FoOptimizeResultVerboseLine -Result $err -Unit (Get-FoSizeDisplayUnit -Settings $settings)
                    }
                    if (-not $ContinueOnError) { throw }
                }
            }
            elseif ($WhatIfPreference) {
                $result = Invoke-FoPluginChain -Path $file -Settings $settings -ShowProgress:$false -Confirm:$false
                $script:FoBatchResults.Add($result)
                if ($verbosity -eq 'Verbose' -and $settings.LogLevel -ge 1) {
                    Write-FoOptimizeResultVerboseLine -Result $result -Unit (Get-FoSizeDisplayUnit -Settings $settings)
                }
            }
        }
    }

    end {
        if ($script:FoBatchSettings -and $script:FoBatchResults.Count -gt 0) {
            $verbosity = Get-FoReportVerbosity -Settings $script:FoBatchSettings
            # Verbose lines are emitted per file during process; Compact/Standard summarize at end.
            if ($verbosity -ne 'Verbose') {
                Write-FoOptimizeResults -Results @($script:FoBatchResults) -Settings $script:FoBatchSettings
            }

            if ($script:FoBatchSettings.ReportPath) {
                Write-FoReport -Results @($script:FoBatchResults) -Settings $script:FoBatchSettings -ReportPath $script:FoBatchSettings.ReportPath
            }
        }
        return @($script:FoBatchResults)
    }
}
