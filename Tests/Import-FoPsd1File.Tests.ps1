BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Import-FoPsd1File' -Tag Unit {
    It 'Loads committed module data files' {
        $decisionsPath = Join-Path $PSScriptRoot 'ImageTestDecisions.psd1'
        $data = Import-FoPsd1File -Path $decisionsPath
        $data.JpegSSIMFallbackMaximum | Should -Be 0
        $data.PngDssimDissimilarityMaximum | Should -Be 0
    }

    It 'Loads nested hashtable data' {
        $mapPath = Join-Path (Get-FoTestModuleRoot) 'Data\ExtensionMap.psd1'
        $data = Import-FoPsd1File -Path $mapPath
        $data['.png'] | Should -Be @('PNG')
        $data['.docx'] | Should -Be @('ZIP')
    }
}

Describe 'Import-FoJsonFile' -Tag Unit {
    It 'Loads config template defaults' {
        $templatePath = Join-Path (Get-FoTestModuleRoot) 'Templates\Config.defaults.json'
        $data = Import-FoJsonFile -Path $templatePath
        $data.Level | Should -Be 5
        $data.OutputMode | Should -Be 'TempMove'
        $data.PluginTimeoutSeconds | Should -Be 1800
    }
}
