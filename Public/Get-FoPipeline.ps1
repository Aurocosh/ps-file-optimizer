function Get-FoPipeline {
    <#
    .SYNOPSIS
    Returns pipeline steps for a format group.

    .DESCRIPTION
    Invokes the Get-Fo{GroupName}Pipeline function for the supplied context hashtable.
    Use Get-FoExecutionPlan to resolve active steps, tool availability, and file context.

    .PARAMETER GroupName
    Pipeline group name (PNG, JPEG, PDF, ZIP, etc.).

    .PARAMETER Context
    File context hashtable from New-FoFileContext.

    .EXAMPLE
    $ctx = New-FoFileContext -InputFile .\photo.png -Settings (Get-FoConfig)
    Get-FoPipeline -GroupName PNG -Context $ctx
    #>
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
    <#
    .SYNOPSIS
    Builds an optimization execution plan for a file.

    .DESCRIPTION
    Resolves pipeline groups, active steps (after gates), and missing plugin tools
    for the given path and settings. Used by Invoke-FoPluginChain and debugging tools.

    .PARAMETER Path
    Path to the file to optimize.

    .PARAMETER Settings
    Merged settings hashtable from Get-FoConfig.

    .EXAMPLE
    $settings = Get-FoConfig
    Get-FoExecutionPlan -Path .\image.png -Settings $settings
    #>
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
