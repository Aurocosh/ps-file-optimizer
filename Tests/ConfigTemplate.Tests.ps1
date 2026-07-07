BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Config template' -Tag Unit {
    It 'Contains every key from Get-FoModuleDefaults' {
        $defaults = Get-FoModuleDefaults
        $templatePath = Join-Path (Get-FoTestModuleRoot) 'Templates\Config.defaults.psd1'
        $template = Import-FoDataFile -Path $templatePath

        $defaultKeys = @($defaults.Keys | Sort-Object)
        $templateKeys = @($template.Keys | Sort-Object)

        $templateKeys | Should -Be $defaultKeys
    }
}

Describe 'Module public API' -Tag Unit {
    BeforeAll {
        if (-not (Get-Module -Name FileOptimizer)) {
            Import-Module (Join-Path (Get-FoTestModuleRoot) 'FileOptimizer.psd1') -Force
        }
    }

    It 'Exports only the intended cmdlets' {
        $expected = @(
            'Get-FoConfig'
            'Get-FoExecutionPlan'
            'Get-FoHistory'
            'Get-FoPipeline'
            'Initialize-FoConfig'
            'Install-FoDssim'
            'Install-FoPlugins'
            'Invoke-FoPluginChain'
            'Optimize-FoFile'
            'Resolve-FoPluginExecutable'
            'Undo-FoOptimization'
        )

        $exported = @(Get-Command -Module FileOptimizer | Select-Object -ExpandProperty Name | Sort-Object)
        $exported | Should -Be $expected
    }

    It 'Passes Test-ModuleManifest' {
        $manifestPath = Join-Path (Get-FoTestModuleRoot) 'FileOptimizer.psd1'
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
    }
}

Describe 'Get-FoHistory -Format Object' -Tag Unit {
    It 'Returns structured entries without writing to the host' {
        $histDir = Join-Path $TestDrive 'history-object'
        New-Item -ItemType Directory -Path $histDir -Force | Out-Null
        $histFile = Join-Path $histDir 'history.psd1'

        @"
@{
    Version = 1
    Entries = @(
        @{
            Id = 'test-id-1'
            Timestamp = '2026-01-01T00:00:00Z'
            OriginalPath = 'C:\data\photo.png'
            OptimizedPath = 'C:\data\photo.png'
            OriginalSize = 1000
            FinalSize = 800
            BytesSaved = 200
            OutputMode = 'TempMove'
            ReversalStatus = 'Pending'
        }
    )
}
"@ | Set-Content -LiteralPath $histFile -Encoding UTF8

        $entries = @(Get-FoHistory -HistoryPath $histFile -Format Object -Id 'test-id-1')

        $entries.Count | Should -Be 1
        $entries[0].Id | Should -Be 'test-id-1'
        $entries[0].BytesSaved | Should -Be 200
    }
}
