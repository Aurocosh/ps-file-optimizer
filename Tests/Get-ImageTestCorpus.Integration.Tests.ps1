$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

$script:FoCorpusIntegrationEnabled = [bool]$env:FO_RUN_CORPUS_INTEGRATION

Describe 'Get-ImageTestCorpus integration' {
    It 'Downloads Tier B from aux release and extracts expected file count' -Skip:(-not $script:FoCorpusIntegrationEnabled) {
        $corpusRoot = Join-Path $env:TEMP "FoCorpusIntegration_$(Get-Random)"
        $scriptPath = Join-Path $moduleRoot 'Scripts\Get-ImageTestCorpus.ps1'

        try {
            $result = & $scriptPath -Tier B -Destination $corpusRoot -Force
            $result.Downloaded | Should -Be $true
            $result.Extracted | Should -Be $true
            $result.FileCount | Should -Be 318

            $presence = Test-FoImageTestFixturesPresent -Tier B -CorpusRoot $corpusRoot
            $presence.Present | Should -Be $true
            $presence.Count | Should -Be 318

            Test-Path -LiteralPath (Join-Path $corpusRoot 'tier-b\pngsuite\basn0g01.png') | Should -Be $true
        }
        finally {
            Remove-Item -LiteralPath $corpusRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
