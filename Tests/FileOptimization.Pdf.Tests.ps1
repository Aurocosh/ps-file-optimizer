BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'PDF pipeline behavior' -Tag Unit {
    It 'Selects 64-bit Ghostscript for Plugins64 path' {
        $settings = Get-FoConfig
        $settings.PluginPath = Join-Path $TestDrive 'Plugins64'
        $ctx = @{
            Settings     = $settings
            IsPDFLayered = $false
            Extension    = '.pdf'
        }

        $steps = Get-FoPipeline -GroupName PDF -Context $ctx
        $gs = $steps | Where-Object { $_.Name -like 'Ghostscript*' } | Select-Object -First 1
        $gs.Executable | Should -Be 'gswin64c.exe'
    }

    It 'Selects 32-bit Ghostscript for Plugins32 path' {
        $settings = Get-FoConfig
        $settings.PluginPath = Join-Path $TestDrive 'Plugins32'
        $ctx = @{
            Settings     = $settings
            IsPDFLayered = $false
            Extension    = '.pdf'
        }

        $steps = Get-FoPipeline -GroupName PDF -Context $ctx
        $gs = $steps | Where-Object { $_.Name -like 'Ghostscript*' } | Select-Object -First 1
        $gs.Executable | Should -Be 'gswin32c.exe'
    }

    It 'Skips all layered-sensitive PDF steps when layered skip is enabled' {
        $settings = Get-FoConfig
        $settings.PDFSkipLayered = $true
        $settings.PDFProfile = 'ebook'
        $ctx = @{
            Settings     = $settings
            IsPDFLayered = $true
            Extension    = '.pdf'
        }

        @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName PDF -Context $ctx) -Context $ctx).Count | Should -Be 0
    }

    It 'Allows layered PDF steps when profile is none' {
        $settings = Get-FoConfig
        $settings.PDFSkipLayered = $true
        $settings.PDFProfile = 'none'
        $ctx = @{
            Settings     = $settings
            IsPDFLayered = $true
            Extension    = '.pdf'
        }

        @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName PDF -Context $ctx) -Context $ctx).Count | Should -BeGreaterThan 0
    }

    It 'Allows layered PDF steps when PDFSkipLayered is enabled and PDFProfile uses module default' {
        $settings = Get-FoModuleDefaults
        $settings.PDFSkipLayered = $true
        $ctx = @{
            Settings     = $settings
            IsPDFLayered = $true
            Extension    = '.pdf'
        }

        $settings.PDFProfile | Should -Be 'none'
        @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName PDF -Context $ctx) -Context $ctx).Count | Should -BeGreaterThan 0
    }
}
