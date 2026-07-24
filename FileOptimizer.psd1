@{
    ModuleVersion     = '1.0.4'
    GUID              = 'a47c8e21-5f3b-4d92-9c1a-6e8b2d4f7c90'
    Author            = 'Aurocosh'
    Copyright         = '(c) PS-FileOptimizer contributors. FileOptimizer plugins are subject to their respective licenses.'
    Description       = 'PowerShell module mirroring FileOptimizer plugin optimization chains with a scriptable CLI.'
    PowerShellVersion = '5.1'
    RootModule        = 'FileOptimizer.psm1'
    FunctionsToExport = @(
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
    PrivateData       = @{
        PSData = @{
            Tags         = @('FileOptimizer', 'compression', 'optimization', 'PNG', 'CLI')
            LicenseUri   = 'https://www.gnu.org/licenses/agpl-3.0.html'
            ProjectUri   = 'https://github.com/Aurocosh/ps-file-optimizer'
            ReleaseNotes = 'Install-FoPlugins FullPortable now includes TruePNG and PNGOut. See ReleaseNotes/1.0.4.md.'
        }
    }
}
