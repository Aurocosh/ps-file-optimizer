function New-FoStep {
    param(
        [string]$Name,
        [string]$Executable,
        [string]$Arguments,
        [string]$Handler,
        [ValidateSet('TempInput', 'TempOutput', 'InPlace')]
        [string]$Mode = 'TempInput',
        [scriptblock]$Gate,
        [int]$ErrorMin = 0,
        [int]$ErrorMax = 0
        # ErrorMin/ErrorMax let pipeline authors accept non-zero plugin exit codes for a step
        # (for example, some tools return 1 on “success with warnings” or 2 for “already optimized”).
    )

    [PSCustomObject]@{
        Name       = $Name
        Executable = $Executable
        Arguments  = $Arguments
        Handler    = $Handler
        Mode       = $Mode
        Gate       = $Gate
        ErrorMin   = $ErrorMin
        ErrorMax   = $ErrorMax
    }
}

function Test-FoStepExitCodeAccepted {
    param(
        [Parameter(Mandatory)]
        $Step,
        [Parameter(Mandatory)]
        [int]$ExitCode
    )

    $min = 0
    $max = 0
    if ($null -ne $Step.PSObject.Properties['ErrorMin']) { $min = [int]$Step.ErrorMin }
    if ($null -ne $Step.PSObject.Properties['ErrorMax']) { $max = [int]$Step.ErrorMax }

    if ($min -eq 0 -and $max -eq 0) {
        return $ExitCode -eq 0
    }

    return $ExitCode -ge $min -and $ExitCode -le $max
}

function Get-FoActiveSteps {
    param(
        [array]$Steps,
        [hashtable]$Context
    )

    foreach ($step in $Steps) {
        if ($step.Gate) {
            if (-not (& $step.Gate $Context)) { continue }
        }
        $step
    }
}

function Test-FoPipelineTools {
    param(
        [array]$Steps,
        [string]$SearchMode,
        [string]$PluginPath
    )

    $missing = [System.Collections.Generic.List[string]]::new()
    foreach ($step in $Steps) {
        foreach ($exe in (Get-FoStepRequiredExecutables -Step $step)) {
            $r = Resolve-FoPluginExecutable -Name $exe -SearchMode $SearchMode -PluginPath $PluginPath
            if (-not $r.Found) { $missing.Add($exe) }
        }
    }
    return @($missing | Select-Object -Unique)
}
