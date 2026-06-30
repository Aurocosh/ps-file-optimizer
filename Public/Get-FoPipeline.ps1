function Get-FoPipeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupName,
        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    $fn = "Get-Fo${GroupName}Pipeline"
    if (-not (Get-Command -Name $fn -ErrorAction SilentlyContinue)) {
        Write-Warning "Pipeline not defined: $GroupName"
        return @()
    }
    return & $fn -Context $Context
}

function Get-FoExecutionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [hashtable]$Settings
    )

    $context = New-FoFileContext -InputFile $Path -Settings $Settings
    $groups = Get-FoPipelineGroupsForFile -Path $Path
    $plans = @()

    foreach ($group in $groups) {
        $allSteps = Get-FoPipeline -GroupName $group -Context $context
        $active = @(Get-FoActiveSteps -Steps $allSteps -Context $context)
        $missing = Test-FoPipelineTools -Steps $active -SearchMode $Settings.PluginSearchMode -PluginPath $Settings.PluginPath
        $plans += [PSCustomObject]@{
            GroupName = $group
            Steps     = $active
            Missing   = $missing
        }
    }

    return [PSCustomObject]@{
        Context = $context
        Plans   = $plans
    }
}
