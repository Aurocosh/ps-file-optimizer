function Get-FoEnginePrivateScriptNames {
    return @(
        'Import-FoPsd1File'
        'Import-FoJsonFile'
        'Get-FoModuleDefaults'
        'Format-FoFileSize'
        'Merge-FoSettings'
        'Write-FoLog'
        'Get-FoLevelFlags'
        'Get-ExtensionByContent'
        'Test-FoFileGate'
        'Get-FoStepRequiredExecutables'
        'Get-FoPipelineExecutableInventory'
        'Invoke-FoPlugin'
        'Invoke-FoOutputMode'
        'Add-FoHistoryEntry'
        'Format-FoHistoryEntry'
        'Write-FoReport'
        'Write-FoOptimizeResult'
        'Get-FoTargetFiles'
        'Invoke-FoRollback'
    )
}

function Get-FoTestSupportPrivateScriptNames {
    return @(
        'Import-FoPsd1File'
        'Import-FoJsonFile'
        'Get-FoModuleDefaults'
        'Format-FoFileSize'
        'Merge-FoSettings'
        'Get-FoLevelFlags'
        'Get-ExtensionByContent'
        'Test-FoFileGate'
        'Invoke-FoOutputMode'
        'Add-FoHistoryEntry'
        'Format-FoHistoryEntry'
    )
}
