function New-FoStep {
    param(
        [string]$Name,
        [string]$Executable,
        [string]$Arguments,
        [string]$Handler,
        [ValidateSet('TempInput', 'TempOutput', 'InPlace')]
        [string]$Mode = 'TempInput',
        [scriptblock]$Gate
    )

    [PSCustomObject]@{
        Name       = $Name
        Executable = $Executable
        Arguments  = $Arguments
        Handler    = $Handler
        Mode       = $Mode
        Gate       = $Gate
    }
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
