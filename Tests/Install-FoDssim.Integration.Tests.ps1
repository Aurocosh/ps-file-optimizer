BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Install-FoDssim integration' -Tag Integration -Skip:(-not $env:FO_RUN_INSTALL_INTEGRATION) {
    It 'Downloads dssim, installs to plugins/dssim/dssim.exe, and cleans temporary files' -Skip:(-not [Environment]::Is64BitProcess) {
        $dest = Join-Path $env:TEMP "FoDssimIntegration_dest_$(Get-Random)"
        $tempRoot = Join-Path $env:TEMP "FoDssimIntegration_temp_$(Get-Random)"
        New-Item -ItemType Directory -Path $dest -Force | Out-Null

        try {
            $result = Install-FoDssim -DestinationPath $dest -TempDirectory $tempRoot -Force

            $result.Downloaded | Should -Be $true
            $result.Extracted | Should -Be $true
            $result.Skipped | Should -Be $false
            $result.Version | Should -Be '3.4.0'
            Test-Path -LiteralPath $result.InstalledPath | Should -Be $true
            (Get-Item -LiteralPath $result.InstalledPath).Length | Should -BeGreaterThan 0
            Test-Path -LiteralPath $tempRoot | Should -Be $false
            Test-FoDssimCompareAvailable -PluginPath $dest | Should -Be $true
        }
        finally {
            Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
