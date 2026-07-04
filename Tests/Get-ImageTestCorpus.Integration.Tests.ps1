BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Get-ImageTestCorpus integration' -Tag Integration -Skip:(-not $env:FO_RUN_CORPUS_INTEGRATION) {
    It 'Downloads Tier B from aux release and extracts expected file count' {
        $corpusRoot = Join-Path $env:TEMP "FoCorpusIntegration_$(Get-Random)"
        $scriptPath = Join-Path (Get-FoTestModuleRoot) 'Scripts\Get-ImageTestCorpus.ps1'

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
