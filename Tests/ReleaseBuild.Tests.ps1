BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Release packaging' -Tag Unit {
    It 'Build-FoModuleRelease.ps1 creates a versioned module zip' {
        $moduleRoot = Get-FoTestModuleRoot
        $manifestPath = Join-Path $moduleRoot 'FileOptimizer.psd1'
        $expectedVersion = [version](Import-FoPsd1File -Path $manifestPath).ModuleVersion

        $outputDir = Join-Path $TestDrive 'release-dist'
        $buildScript = Join-Path $moduleRoot 'Scripts\Build-FoModuleRelease.ps1'

        $result = & $buildScript -ModuleRoot $moduleRoot -OutputDirectory $outputDir

        $result.Version | Should -Be $expectedVersion
        Test-Path -LiteralPath $result.ArchivePath | Should -Be $true

        $extractRoot = Join-Path $TestDrive 'release-extract'
        Expand-Archive -LiteralPath $result.ArchivePath -DestinationPath $extractRoot -Force

        $packagedManifestPath = Join-Path (Join-Path (Join-Path $extractRoot 'FileOptimizer') $expectedVersion.ToString()) 'FileOptimizer.psd1'
        Test-Path -LiteralPath $packagedManifestPath | Should -Be $true
    }
}
