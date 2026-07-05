BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Install-FoPlugins integration (x64)' -Tag Integration -Skip:(-not $env:FO_RUN_INSTALL_INTEGRATION) {
    It 'Downloads x64 plugin bundle, installs to Plugins64, and cleans temporary files' {
        Test-FoPluginInstallIntegrationCore -Architecture 64 -FolderName 'Plugins64' `
            -GhostscriptExe 'gswin64c.exe' -GhostscriptDll 'gsdll64.dll'
    }
}

Describe 'Install-FoPlugins integration (x86)' -Tag Integration -Skip:(-not $env:FO_RUN_INSTALL_INTEGRATION) {
    It 'Downloads x86 plugin bundle, installs to Plugins32, and cleans temporary files' {
        Test-FoPluginInstallIntegrationCore -Architecture 32 -FolderName 'Plugins32' `
            -GhostscriptExe 'gswin32c.exe' -GhostscriptDll 'gsdll32.dll'
    }
}
