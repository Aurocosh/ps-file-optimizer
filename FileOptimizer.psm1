$script:FoModuleRoot = $PSScriptRoot
$script:FoExtensionMap = $null

# Private helpers
. (Join-Path $PSScriptRoot 'Private\Import-FoDataFile.ps1')
. (Join-Path $PSScriptRoot 'Private\Get-FoModuleDefaults.ps1')
. (Join-Path $PSScriptRoot 'Private\Format-FoFileSize.ps1')
. (Join-Path $PSScriptRoot 'Private\Merge-FoSettings.ps1')
. (Join-Path $PSScriptRoot 'Private\Write-FoLog.ps1')
. (Join-Path $PSScriptRoot 'Private\Get-FoLevelFlags.ps1')
. (Join-Path $PSScriptRoot 'Private\Get-ExtensionByContent.ps1')
. (Join-Path $PSScriptRoot 'Private\Test-FoFileGate.ps1')
. (Join-Path $PSScriptRoot 'Private\Handlers\Invoke-FoNativeHandlers.ps1')
. (Join-Path $PSScriptRoot 'Private\Invoke-FoPlugin.ps1')
. (Join-Path $PSScriptRoot 'Private\Invoke-FoOutputMode.ps1')
. (Join-Path $PSScriptRoot 'Private\Add-FoHistoryEntry.ps1')
. (Join-Path $PSScriptRoot 'Private\Format-FoHistoryEntry.ps1')
. (Join-Path $PSScriptRoot 'Private\Write-FoReport.ps1')
. (Join-Path $PSScriptRoot 'Private\Expand-Fo7zArchive.ps1')

# Pipelines
. (Join-Path $PSScriptRoot 'Pipelines\_Helpers.ps1')
Get-ChildItem -Path (Join-Path $PSScriptRoot 'Pipelines\*.ps1') -Exclude '_Helpers.ps1' | ForEach-Object {
    . $_.FullName
}

# Public cmdlets
. (Join-Path $PSScriptRoot 'Public\Resolve-FoPluginExecutable.ps1')
. (Join-Path $PSScriptRoot 'Private\Get-FoPluginBundleMetadata.ps1')
. (Join-Path $PSScriptRoot 'Private\Install-FoPluginBundle.ps1')
. (Join-Path $PSScriptRoot 'Public\Get-FoConfig.ps1')
. (Join-Path $PSScriptRoot 'Public\Initialize-FoConfig.ps1')
. (Join-Path $PSScriptRoot 'Public\Get-FoPipeline.ps1')
. (Join-Path $PSScriptRoot 'Public\Invoke-FoPluginChain.ps1')
. (Join-Path $PSScriptRoot 'Public\Optimize-FoFile.ps1')
. (Join-Path $PSScriptRoot 'Public\Get-FoHistory.ps1')
. (Join-Path $PSScriptRoot 'Public\Undo-FoOptimization.ps1')
. (Join-Path $PSScriptRoot 'Public\Install-FoPlugins.ps1')

Export-ModuleMember -Function @(
    'Optimize-FoFile'
    'Get-FoPipeline'
    'Invoke-FoPluginChain'
    'Resolve-FoPluginExecutable'
    'Get-FoConfig'
    'Initialize-FoConfig'
    'Undo-FoOptimization'
    'Get-FoHistory'
    'Install-FoPlugins'
)
