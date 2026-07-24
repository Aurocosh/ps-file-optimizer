BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Config template' -Tag Unit {
    It 'Contains every key from Get-FoModuleDefaults' {
        $defaults = Get-FoModuleDefaults
        $templatePath = Join-Path (Get-FoTestModuleRoot) 'Templates\Config.defaults.json'
        $template = Import-FoJsonFile -Path $templatePath

        $defaultKeys = @($defaults.Keys | Sort-Object)
        $templateKeys = @($template.Keys | Sort-Object)

        $templateKeys | Should -Be $defaultKeys
    }

    It 'Defaults PDFProfile to none for FileOptimizer parity' {
        (Get-FoModuleDefaults).PDFProfile | Should -Be 'none'
    }

    It 'Accepts default output suffix settings' {
        $defaults = Get-FoModuleDefaults
        { Test-FoSafeSuffix -Value $defaults.BackupSuffix -SettingName 'BackupSuffix' } | Should -Not -Throw
        { Test-FoSafeSuffix -Value $defaults.OptimizedSuffix -SettingName 'OptimizedSuffix' } | Should -Not -Throw
    }

    It 'Rejects unsafe OptimizedSuffix values during settings merge' {
        { Merge-FoSettings -BoundParameters @{ OptimizedSuffix = '\..\escape' } } |
            Should -Throw "*OptimizedSuffix*"
    }

    It 'Clamps Level to 0-9 during settings merge' {
        (Merge-FoSettings -BoundParameters @{ Level = 15 }).Level | Should -Be 9
        (Merge-FoSettings -BoundParameters @{ Level = -3 }).Level | Should -Be 0
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
        $histFile = Join-Path $histDir 'history.json'

        @'
{
  "Version": 1,
  "Entries": [
    {
      "Id": "test-id-1",
      "BatchId": "batch-a",
      "Timestamp": "2026-01-01T00:00:00Z",
      "OriginalPath": "C:\\data\\photo.png",
      "OptimizedPath": "C:\\data\\photo.png",
      "OriginalSize": 1000,
      "FinalSize": 800,
      "BytesSaved": 200,
      "OutputMode": "TempMove",
      "ReversalStatus": "Pending"
    }
  ]
}
'@ | Set-Content -LiteralPath $histFile -Encoding UTF8

        $entries = @(Get-FoHistory -HistoryPath $histFile -Format Object -Id 'test-id-1')

        $entries.Count | Should -Be 1
        $entries[0].Id | Should -Be 'test-id-1'
        $entries[0].BatchId | Should -Be 'batch-a'
        $entries[0].BytesSaved | Should -Be 200
    }

    It 'Filters by LastBatches using BatchId' {
        $histDir = Join-Path $TestDrive 'history-batches'
        New-Item -ItemType Directory -Path $histDir -Force | Out-Null
        $histFile = Join-Path $histDir 'history.json'

        @'
{
  "Version": 1,
  "Entries": [
    {
      "Id": "old-1",
      "BatchId": "batch-old",
      "Timestamp": "2026-01-01T00:00:00",
      "OriginalPath": "C:\\a.png",
      "OptimizedPath": "C:\\a.png",
      "OriginalSize": 10,
      "FinalSize": 5,
      "OutputMode": "TempMove",
      "ReversalStatus": "Pending"
    },
    {
      "Id": "new-1",
      "BatchId": "batch-new",
      "Timestamp": "2026-01-02T00:00:00",
      "OriginalPath": "C:\\b.png",
      "OptimizedPath": "C:\\b.png",
      "OriginalSize": 10,
      "FinalSize": 5,
      "OutputMode": "TempMove",
      "ReversalStatus": "Pending"
    },
    {
      "Id": "new-2",
      "BatchId": "batch-new",
      "Timestamp": "2026-01-02T00:01:00",
      "OriginalPath": "C:\\c.png",
      "OptimizedPath": "C:\\c.png",
      "OriginalSize": 10,
      "FinalSize": 5,
      "OutputMode": "TempMove",
      "ReversalStatus": "Pending"
    }
  ]
}
'@ | Set-Content -LiteralPath $histFile -Encoding UTF8

        $entries = @(Get-FoHistory -HistoryPath $histFile -Format Object -LastBatches 1)
        $entries.Count | Should -Be 2
        @($entries | ForEach-Object BatchId | Select-Object -Unique) | Should -Be @('batch-new')
    }
}

Describe 'History BatchId' -Tag Unit {
    It 'Stores BatchId on new history entries' {
        InModuleScope FileOptimizer {
            $histDir = Join-Path $TestDrive 'history-add-batch'
            New-Item -ItemType Directory -Path $histDir -Force | Out-Null
            $histFile = Join-Path $histDir 'history.json'
            $settings = @{
                HistoryEnabled = $true
                HistoryPath    = $histFile
            }
            $result = [PSCustomObject]@{
                Path         = 'C:\data\photo.png'
                OriginalSize = 100
                FinalSize    = 50
                OutputPath   = 'C:\data\photo.png'
                BackupPath   = 'C:\tmp\photo.png'
                OutputMode   = 'TempMove'
            }
            Add-FoHistoryEntry -Result $result -Settings $settings -BatchId 'batch-xyz'
            $data = Get-FoHistoryData -HistoryPath $histFile
            $data.Entries[0].BatchId | Should -Be 'batch-xyz'
            $result.BatchId | Should -Be 'batch-xyz'
        }
    }
}
