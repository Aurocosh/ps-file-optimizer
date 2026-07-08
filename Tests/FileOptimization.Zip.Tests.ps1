BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'ZIP pipeline behavior' -Tag Unit {
    It 'Adds non-recursive ECT disable flags by default' {
        $settings = Get-FoConfig
        $settings.ZIPRecurse = $false
        $settings.ZIPCopyMetadata = $false
        $ctx = @{
            Settings = $settings
            IsZipSFX = $false
        }

        $steps = Get-FoPipeline -GroupName ZIP -Context $ctx
        $ectStep = $steps | Where-Object { $_.Name -like 'ECT*' } | Select-Object -First 1
        $ectStep.Arguments | Should -Match '--disable-png'
        $ectStep.Arguments | Should -Match '--disable-jpg'
        $ectStep.Arguments | Should -Match '-strip'
    }

    It 'Enables ZIP recurse flags when ZIPRecurse is true' {
        $settings = Get-FoConfig
        $settings.ZIPRecurse = $true
        $settings.ZIPCopyMetadata = $false
        $ctx = @{
            Settings = $settings
            IsZipSFX = $false
        }

        $steps = Get-FoPipeline -GroupName ZIP -Context $ctx
        $leanify = $steps | Where-Object { $_.Name -like 'Leanify*' } | Select-Object -First 1
        $ectStep = $steps | Where-Object { $_.Name -like 'ECT*' } | Select-Object -First 1

        $leanify.Arguments | Should -Match '--zip-deflate -d 1'
        $ectStep.Arguments | Should -Not -Match '--disable-png|--disable-jpg'
        $ectStep.Arguments | Should -Match '-strip'
    }

    It 'Copies ZIP entry metadata when ZIPCopyMetadata is true' {
        $settings = Get-FoConfig
        $settings.ZIPRecurse = $false
        $settings.ZIPCopyMetadata = $true
        $ctx = @{
            Settings = $settings
            IsZipSFX = $false
        }

        $steps = Get-FoPipeline -GroupName ZIP -Context $ctx

        $leanify = $steps | Where-Object { $_.Name -like 'Leanify*' } | Select-Object -First 1
        $ectStep = $steps | Where-Object { $_.Name -like 'ECT*' } | Select-Object -First 1
        $deflOpts = @($steps | Where-Object { $_.Name -like 'DeflOpt*' })

        $leanify.Arguments | Should -Match '--keep-exif'
        $ectStep.Arguments | Should -Not -Match '-strip'
        ($deflOpts | ForEach-Object { $_.Arguments }) | Should -Match '/c'
    }

    It 'Skips advzip step for ZIP SFX context' {
        $settings = Get-FoConfig
        $ctx = @{
            Settings = $settings
            IsZipSFX = $true
        }

        $active = @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName ZIP -Context $ctx) -Context $ctx)
        @($active | Where-Object { $_.Name -like 'advzip*' }).Count | Should -Be 0
    }
}
