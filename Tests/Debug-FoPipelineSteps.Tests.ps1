BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Debug-FoPipelineSteps' -Tag ImageIntegration -Skip:(-not (Test-FoPluginsAvailable)) {
    BeforeAll {
        $script:PluginPath = Get-FoTestPluginPath
        $script:Settings = Get-FoImageTestProfile -Name 'LosslessDefault' -PluginPath $script:PluginPath
        $script:WorkDir = Join-Path $TestDrive 'pipeline-debug'
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
        $script:DebugScript = Join-Path (Get-FoTestModuleRoot) 'Scripts\Debug-FoPipelineSteps.ps1'
    }

    It 'Reports all steps passing on a lossless PNG fixture' {
        $fixture = Join-Path $script:WorkDir 'debug-generated-64x64.png'
        New-FoTestPng -Path $fixture -Width 64 -Height 64
        $workDir = Join-Path $script:WorkDir 'png-generated-debug'
        $allowDssim = (Test-FoCompareAllowMissingDssim) -or (-not (Test-FoDssimCompareAvailable -PluginPath $script:PluginPath))

        $result = & $script:DebugScript -Path $fixture -ProfileName 'LosslessDefault' `
            -PluginPath $script:PluginPath -WorkDirectory $workDir -AllowMissingDssim:$allowDssim

        $result.AllPassed | Should -Be $true
        $result.FirstFailure | Should -BeNullOrEmpty
        ($result.StepResults.Count -gt 0) | Should -Be $true
        ($result.StepResults | Where-Object { -not $_.ComparePass }).Count | Should -Be 0
    }

    It 'Identifies corruption when output is replaced after the first step' {
        $fixture = Join-Path $script:WorkDir 'debug-corrupt-source.png'
        New-FoTestPng -Path $fixture -Width 64 -Height 64
        $workDir = Join-Path $script:WorkDir 'injected-failure'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null

        $before = Join-Path $workDir 'before.png'
        $work = Join-Path $workDir 'work.png'
        Copy-Item -LiteralPath $fixture -Destination $before -Force
        Copy-Item -LiteralPath $fixture -Destination $work -Force

        $plan = Get-FoExecutionPlan -Path $work -Settings $script:Settings
        $firstStep = $plan.Plans[0].Steps[0]

        Invoke-FoPlugin -Step $firstStep -InputFile $work -Settings $script:Settings `
            -PluginPath $script:PluginPath -SearchMode $script:Settings.PluginSearchMode | Out-Null

        $magick = (Resolve-FoPluginExecutable -Name 'magick.exe' -SearchMode PortableOnly -PluginPath $script:PluginPath).Path
        $magickDir = Split-Path -Parent $magick
        Invoke-FoMagickCli -MagickExe $magick -WorkingDirectory $magickDir -ArgumentList @(
            $work, '-fill', 'red', '-draw', 'point 0,0', $work
        ) | Out-Null

        $decisions = Get-FoImageTestDecisions
        $allowDssim = (Test-FoCompareAllowMissingDssim) -or (-not (Test-FoDssimCompareAvailable -PluginPath $script:PluginPath))
        $compare = Compare-FoImage -Before $before -After $work -Mode Pixel -PluginPath $script:PluginPath `
            -PngDssimDissimilarityMaximum $decisions.PngDssimDissimilarityMaximum `
            -AllowMissingDssim:$allowDssim

        $compare.Pass | Should -Be $false
    }
}
