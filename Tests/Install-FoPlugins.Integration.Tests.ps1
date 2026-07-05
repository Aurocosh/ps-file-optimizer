BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

function Test-FoPluginInstallIntegrationCore {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('32', '64')]
        [string]$Architecture,
        [Parameter(Mandatory)]
        [string]$FolderName,
        [Parameter(Mandatory)]
        [string]$GhostscriptExe,
        [Parameter(Mandatory)]
        [string]$GhostscriptDll
    )

    $moduleRoot = Join-Path $env:TEMP "FoInstallIntegration_${Architecture}_mod_$(Get-Random)"
    $dest = Join-Path $moduleRoot $FolderName
    $tempRoot = Join-Path $env:TEMP "FoInstallIntegration_${Architecture}_temp_$(Get-Random)"
    New-Item -ItemType Directory -Path $dest -Force | Out-Null

    try {
        $result = Install-FoPlugins -Mode FullPortable -Architecture $Architecture -DestinationPath $dest -TempDirectory $tempRoot

        $result.Architecture | Should -Be $Architecture
        $result.DestinationPath | Should -Be ([System.IO.Path]::GetFullPath($dest))
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

        $gs = Resolve-FoPluginExecutable -Name $GhostscriptExe -SearchMode PortableOnly -PluginPath $dest
        $gs.Found | Should -Be $true
        Test-Path -LiteralPath (Join-Path $dest $GhostscriptDll) | Should -Be $true

        Test-Path -LiteralPath (Join-Path $dest 'tidy.config') | Should -Be $true

        $complete = Install-FoPlugins -Mode Missing -Architecture $Architecture -DestinationPath $dest
        $complete.Downloaded | Should -Be $false
        $complete.Extracted | Should -Be $false
        ($complete.ExecutablesNeeded.Count) | Should -Be 0

        Remove-Item -LiteralPath (Join-Path $dest 'oxipng.exe') -Force
        $missingOne = Install-FoPlugins -Mode Missing -Architecture $Architecture -DestinationPath $dest `
            -TempDirectory (Join-Path $env:TEMP "FoInstallIntegration_${Architecture}_temp2_$(Get-Random)")
        $missingOne.Downloaded | Should -Be $true
        $missingOne.Extracted | Should -Be $true
        ($missingOne.FilesCopied -contains 'oxipng.exe') | Should -Be $true
        (Resolve-FoPluginExecutable -Name 'oxipng.exe' -SearchMode PortableOnly -PluginPath $dest).Found | Should -Be $true
    }
    finally {
        Remove-Item -LiteralPath $moduleRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
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
