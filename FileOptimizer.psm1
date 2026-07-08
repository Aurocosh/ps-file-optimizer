$script:FoModuleRoot = $PSScriptRoot
$script:FoExtensionMap = $null

. (Join-Path $PSScriptRoot 'Private\_Import-FoEngine.ps1')
foreach ($name in (Get-FoEnginePrivateScriptNames)) {
    . (Join-Path $PSScriptRoot "Private\$name.ps1")
}

. (Join-Path $PSScriptRoot 'Private\Handlers\Invoke-FoNativeHandlers.ps1')

. (Join-Path $PSScriptRoot 'Pipelines\_Helpers.ps1')
Get-ChildItem -Path (Join-Path $PSScriptRoot 'Pipelines\*.ps1') -Exclude '_Helpers.ps1' | ForEach-Object {
    . $_.FullName
}

# Public cmdlets
. (Join-Path $PSScriptRoot 'Public\Resolve-FoPluginExecutable.ps1')
. (Join-Path $PSScriptRoot 'Private\Get-FoPluginBundleMetadata.ps1')
. (Join-Path $PSScriptRoot 'Private\Get-FoDssimBundleMetadata.ps1')
. (Join-Path $PSScriptRoot 'Private\Install-FoPluginBundle.ps1')
. (Join-Path $PSScriptRoot 'Private\Install-FoDssimBundle.ps1')
. (Join-Path $PSScriptRoot 'Public\Get-FoConfig.ps1')
. (Join-Path $PSScriptRoot 'Public\Initialize-FoConfig.ps1')
. (Join-Path $PSScriptRoot 'Public\Get-FoPipeline.ps1')
. (Join-Path $PSScriptRoot 'Public\Invoke-FoPluginChain.ps1')
. (Join-Path $PSScriptRoot 'Public\Optimize-FoFile.ps1')
. (Join-Path $PSScriptRoot 'Public\Get-FoHistory.ps1')
. (Join-Path $PSScriptRoot 'Public\Undo-FoOptimization.ps1')
. (Join-Path $PSScriptRoot 'Public\Install-FoPlugins.ps1')
. (Join-Path $PSScriptRoot 'Public\Install-FoDssim.ps1')

Export-ModuleMember -Function @(
    'Optimize-FoFile'
    'Get-FoPipeline'
    'Get-FoExecutionPlan'
    'Invoke-FoPluginChain'
    'Resolve-FoPluginExecutable'
    'Get-FoConfig'
    'Initialize-FoConfig'
    'Undo-FoOptimization'
    'Get-FoHistory'
    'Install-FoPlugins'
    'Install-FoDssim'
)
