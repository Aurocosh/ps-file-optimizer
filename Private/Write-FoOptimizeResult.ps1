function Set-FoOptimizeResultDisplay {
    param(
        [Parameter(Mandatory)]
        $Result
    )

    $display = [string[]]@(
        'Status'
        'Path'
        'OriginalSize'
        'FinalSize'
        'PercentSaved'
        'OutputMode'
        'DurationMs'
        'Reason'
    )
    $propertySet = [System.Management.Automation.PSPropertySet]::new('DefaultDisplayPropertySet', $display)
    $members = [System.Management.Automation.PSMemberInfo[]]@($propertySet)
    $Result | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $members -Force
    return $Result
}

function Get-FoSizeDisplayUnit {
    param([hashtable]$Settings)

    if ($Settings -and $Settings.SizeDisplayUnit) {
        return [string]$Settings.SizeDisplayUnit
    }
    return 'Auto'
}

function Get-FoReportVerbosity {
    param([hashtable]$Settings)

    if ($Settings -and $Settings.ReportVerbosity) {
        return [string]$Settings.ReportVerbosity
    }
    return 'Standard'
}

function Format-FoOptimizeResultRow {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        $Result,
        [ValidateSet('Auto', 'Bytes', 'KB', 'MB', 'GB')]
        [string]$Unit = 'Auto'
    )

    $originalPath = if ($Result.PSObject.Properties['Path']) { [string]$Result.Path } else { $null }
    $outputPath = if ($Result.PSObject.Properties['OutputPath'] -and $Result.OutputPath) {
        [string]$Result.OutputPath
    }
    else {
        $originalPath
    }
    $backupPath = if ($Result.PSObject.Properties['BackupPath']) { $Result.BackupPath } else { $null }
    $outputMode = if ($Result.PSObject.Properties['OutputMode']) { $Result.OutputMode } else { $null }
    $durationMs = if ($Result.PSObject.Properties['DurationMs']) { $Result.DurationMs } else { $null }

    $sizeText = $null
    if ($Result.PSObject.Properties['OriginalSize'] -and $null -ne $Result.OriginalSize) {
        $final = if ($null -ne $Result.FinalSize) { [long]$Result.FinalSize } else { [long]$Result.OriginalSize }
        $sizeText = Format-FoSizeChange -OriginalSize ([long]$Result.OriginalSize) -FinalSize $final -Unit $Unit
    }

    $displayOutput = if ($outputPath -and $originalPath -and
        ([System.IO.Path]::GetFullPath($outputPath) -ieq [System.IO.Path]::GetFullPath($originalPath))) {
        $null
    }
    else {
        $outputPath
    }

    return [PSCustomObject]@{
        Status       = $Result.Status
        OriginalPath = $originalPath
        OutputPath   = $displayOutput
        BackupPath   = $backupPath
        Size         = $sizeText
        OutputMode   = $outputMode
        Duration     = if ($null -ne $durationMs) { '{0} ms' -f $durationMs } else { $null }
        Reason       = if ($Result.PSObject.Properties['Reason']) { $Result.Reason } else { $null }
    }
}

function Write-FoOptimizeResultVerboseLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Result,
        [ValidateSet('Auto', 'Bytes', 'KB', 'MB', 'GB')]
        [string]$Unit = 'Auto'
    )

    $path = $Result.Path
    switch ($Result.Status) {
        'Optimized' {
            Write-Host ('Optimized {0}: {1}' -f $path, (Format-FoSizeChange -OriginalSize $Result.OriginalSize -FinalSize $Result.FinalSize -Unit $Unit))
        }
        'Unchanged' {
            if ($Result.Reason -eq 'MissingTools') {
                $missing = @($Result.Missing)
                $hint = if ($missing.Count -gt 0) {
                    "missing tools: $($missing -join ', ')"
                }
                else {
                    'no plugin tools available'
                }
                Write-Host ("Unchanged {0}: {1} ({2}; check PluginPath or run Install-FoPlugins)" -f $path, (Format-FoFileSize -Bytes $Result.OriginalSize -Unit $Unit), $hint)
            }
            else {
                Write-Host ("Unchanged {0}: {1} (already optimal)" -f $path, (Format-FoFileSize -Bytes $Result.OriginalSize -Unit $Unit))
            }
        }
        'Skipped' {
            Write-Host ("Skipped {0}: {1}" -f $path, $Result.Reason)
        }
        'Error' {
            Write-Host ("Error {0}: {1}" -f $path, $Result.Reason)
        }
        'WhatIf' {
            Write-Host ("WhatIf {0}" -f $path)
        }
        default {
            Write-Host ("{0} {1}" -f $Result.Status, $path)
        }
    }
}

function Format-FoOptimizeResultCompactLine {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        $Result,
        [ValidateSet('Auto', 'Bytes', 'KB', 'MB', 'GB')]
        [string]$Unit = 'Auto'
    )

    $outputPath = if ($Result.OutputPath) { $Result.OutputPath } else { $Result.Path }
    if ($Result.Status -eq 'Optimized' -and $null -ne $Result.OriginalSize) {
        return '{0}: {1}' -f $outputPath, (Format-FoSizeChange -OriginalSize $Result.OriginalSize -FinalSize $Result.FinalSize -Unit $Unit)
    }
    if ($Result.Status -eq 'Unchanged' -and $null -ne $Result.OriginalSize) {
        return '{0}: {1} (unchanged)' -f $outputPath, (Format-FoFileSize -Bytes $Result.OriginalSize -Unit $Unit)
    }
    if ($Result.Status -eq 'Skipped') {
        return '{0}: skipped ({1})' -f $Result.Path, $Result.Reason
    }
    if ($Result.Status -eq 'Error') {
        return '{0}: error ({1})' -f $Result.Path, $Result.Reason
    }
    if ($Result.Status -eq 'WhatIf') {
        $stepCount = if ($Result.Steps) { @($Result.Steps).Count } else { 0 }
        return '{0}: what-if ({1} steps)' -f $Result.Path, $stepCount
    }
    return '{0}: {1}' -f $Result.Path, $Result.Status
}

function Write-FoOptimizeResultCompactLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Result,
        [ValidateSet('Auto', 'Bytes', 'KB', 'MB', 'GB')]
        [string]$Unit = 'Auto'
    )

    Write-Host (Format-FoOptimizeResultCompactLine -Result $Result -Unit $Unit)
}

function Write-FoOptimizeResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Results,
        [hashtable]$Settings
    )

    if (-not $Results -or $Results.Count -eq 0) { return }

    $verbosity = Get-FoReportVerbosity -Settings $Settings
    $unit = Get-FoSizeDisplayUnit -Settings $Settings

    switch ($verbosity) {
        'Compact' {
            foreach ($r in $Results) {
                Write-FoOptimizeResultCompactLine -Result $r -Unit $unit
            }
        }
        'Verbose' {
            foreach ($r in $Results) {
                Write-FoOptimizeResultVerboseLine -Result $r -Unit $unit
            }
        }
        default {
            $rows = @(
                foreach ($r in $Results) {
                    Format-FoOptimizeResultRow -Result $r -Unit $unit
                }
            )
            $table = ($rows | Format-Table -Property Status, OriginalPath, OutputPath, BackupPath, Size, OutputMode, Duration -AutoSize | Out-String)
            if (-not [string]::IsNullOrWhiteSpace($table)) {
                Write-Host $table.TrimEnd()
            }
        }
    }
}
