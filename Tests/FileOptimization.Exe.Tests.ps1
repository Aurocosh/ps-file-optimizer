BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'EXE pipeline behavior' -Tag Unit {
    It 'Skips SFX-sensitive steps for SFX executables' {
        $settings = Get-FoConfig
        $settings.EXEEnableUPX = $true
        $ctx = @{
            Settings = $settings
            IsEXESFX = $true
        }

        $active = @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName EXE -Context $ctx) -Context $ctx)
        $active.Count | Should -Be 0
    }

    It 'Includes base EXE steps and omits UPX when EXEEnableUPX is false' {
        $settings = Get-FoConfig
        $settings.EXEEnableUPX = $false
        $settings.EXEDisablePETrim = $false
        $ctx = @{
            Settings = $settings
            IsEXESFX = $false
        }

        $active = @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName EXE -Context $ctx) -Context $ctx)

        @($active | Where-Object { $_.Name -like 'Leanify*' }).Count | Should -Be 1
        @($active | Where-Object { $_.Name -like 'PETrim*' }).Count | Should -Be 1
        @($active | Where-Object { $_.Name -like 'strip*' }).Count | Should -Be 1
        @($active | Where-Object { $_.Name -like 'UPX*' }).Count | Should -Be 0
    }

    It 'Enables UPX step when EXEEnableUPX is true' {
        $settings = Get-FoConfig
        $settings.EXEEnableUPX = $true
        $ctx = @{
            Settings = $settings
            IsEXESFX = $false
        }

        $active = @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName EXE -Context $ctx) -Context $ctx)
        @($active | Where-Object { $_.Name -like 'UPX*' }).Count | Should -Be 1
    }
}
