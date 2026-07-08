BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'FoTestSupport engine loader sync' -Tag Unit {
    It 'Lists only existing production private scripts' {
        $moduleRoot = Get-FoTestModuleRoot
        . (Join-Path $moduleRoot 'Private\_Import-FoEngine.ps1')

        foreach ($name in (Get-FoEnginePrivateScriptNames)) {
            $path = Join-Path $moduleRoot "Private\$name.ps1"
            Test-Path -LiteralPath $path | Should -Be $true
        }
    }

    It 'Keeps FoTestSupport private script list within production engine list' {
        $moduleRoot = Get-FoTestModuleRoot
        . (Join-Path $moduleRoot 'Private\_Import-FoEngine.ps1')

        $engine = @(Get-FoEnginePrivateScriptNames)
        $support = @(Get-FoTestSupportPrivateScriptNames)

        $support | Should -Be ($support | Where-Object { $_ -in $engine })
    }

    It 'Does not expose compare helpers from the production module' {
        $manifestPath = Join-Path (Get-FoTestModuleRoot) 'FileOptimizer.psd1'
        Import-Module $manifestPath -Force

        Get-Command -Module FileOptimizer -Name Compare-FoImage -ErrorAction SilentlyContinue |
            Should -Be $null
        Get-Command -Module FileOptimizer -Name Get-FoImageInfo -ErrorAction SilentlyContinue |
            Should -Be $null
    }
}
