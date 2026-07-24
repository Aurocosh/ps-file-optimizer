@{
    ModuleVersion     = '1.1.1'
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
            # Plain text only (PowerShell Gallery does not render markdown).
            ReleaseNotes = @'
1.1.1

Fix ReportVerbosity so Compact and Standard actually change host output.

Fixes

- Per-step and detailed WhatIf dumps from Invoke-FoPluginChain are emitted only when ReportVerbosity is Verbose (they previously always printed, so Compact/Standard looked the same).
- Compact mode now summarizes WhatIf results (path: what-if (N steps)).
- Standard mode writes its end-of-run table via Write-Host so it shows consistently when results are captured by the CLI.
- Optimize result objects use a tighter default display set so Steps no longer floods the console.
'@
        }
    }
}
