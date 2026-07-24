@{
    ModuleVersion     = '1.1.0'
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
1.1.0

Report verbosity, size display units, history batches, and show-config.

Features

- SizeDisplayUnit / -SizeDisplayUnit: Auto (default pretty KB/MB/GB), or fixed Bytes, KB, MB, GB.
- ReportVerbosity / -ReportVerbosity:
  - Compact — one line per file (output path and size change)
  - Standard (default) — end-of-run table: paths, backup, size change, OutputMode, Duration
  - Verbose — previous per-file host lines plus per-step size lines
- Optimization history records a BatchId per Optimize-FoFile / Optimize-File.ps1 run.
- Undo-FoOptimization -LastBatches N and Get-FoHistory -LastBatches N (CLI: Undo-Optimization.ps1 / Show-History.ps1).
- Optimize-File.ps1 -ShowConfig prints the merged configuration (Get-FoConfig for module users).
'@
        }
    }
}
