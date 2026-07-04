BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Install-FoPlugins integration' -Tag Integration -Skip:(-not $env:FO_RUN_INSTALL_INTEGRATION) {
    It 'Downloads plugin bundle, installs plugins, and cleans temporary files' {
        $dest = Join-Path $env:TEMP "FoInstallIntegration_dest_$(Get-Random)"
        $tempRoot = Join-Path $env:TEMP "FoInstallIntegration_temp_$(Get-Random)"
        New-Item -ItemType Directory -Path $dest -Force | Out-Null

        try {
            $result = Install-FoPlugins -Mode FullPortable -DestinationPath $dest -TempDirectory $tempRoot

            $result.Downloaded | Should -Be $true
            $result.Extracted | Should -Be $true
            ($result.FilesCopied.Count -gt 50) | Should -Be $true
            ($result.FilesMissing.Count) | Should -Be 0

            Test-Path -LiteralPath $tempRoot | Should -Be $false

            foreach ($exe in @('oxipng.exe', 'defluff.exe', 'qpdf.exe', 'tidy.exe', 'magick.exe', 'sqlite3.exe')) {
                $resolved = Resolve-FoPluginExecutable -Name $exe -SearchMode PortableOnly -PluginPath $dest
                $resolved.Found | Should -Be $true
                (Get-Item -LiteralPath $resolved.Path).Length | Should -BeGreaterThan 0
            }

            if ([Environment]::Is64BitProcess) {
                $gs = Resolve-FoPluginExecutable -Name 'gswin64c.exe' -SearchMode PortableOnly -PluginPath $dest
                $gs.Found | Should -Be $true
                Test-Path -LiteralPath (Join-Path $dest 'gsdll64.dll') | Should -Be $true
            }

            Test-Path -LiteralPath (Join-Path $dest 'tidy.config') | Should -Be $true

            $complete = Install-FoPlugins -Mode Missing -DestinationPath $dest
            $complete.Downloaded | Should -Be $false
            $complete.Extracted | Should -Be $false
            ($complete.ExecutablesNeeded.Count) | Should -Be 0

            Remove-Item -LiteralPath (Join-Path $dest 'oxipng.exe') -Force
            $missingOne = Install-FoPlugins -Mode Missing -DestinationPath $dest -TempDirectory (Join-Path $env:TEMP "FoInstallIntegration_temp2_$(Get-Random)")
            $missingOne.Downloaded | Should -Be $true
            $missingOne.Extracted | Should -Be $true
            ($missingOne.FilesCopied -contains 'oxipng.exe') | Should -Be $true
            (Resolve-FoPluginExecutable -Name 'oxipng.exe' -SearchMode PortableOnly -PluginPath $dest).Found | Should -Be $true
        }
        finally {
            Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
