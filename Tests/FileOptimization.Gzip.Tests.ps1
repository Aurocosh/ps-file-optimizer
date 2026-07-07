BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'GZIP pipeline behavior' -Tag Unit {
    It 'Uses metadata-stripping steps when GZCopyMetadata is false' {
        $settings = Get-FoConfig
        $settings.GZCopyMetadata = $false
        $ctx = @{ Settings = $settings }

        $steps = Get-FoPipeline -GroupName GZIP -Context $ctx
        $active = @(Get-FoActiveSteps -Steps $steps -Context $ctx)

        @($active | Where-Object { $_.Name -like 'GzipRecompress*' }).Count | Should -Be 1
        ($steps | Where-Object { $_.Name -like 'ECT*' } | Select-Object -First 1).Arguments | Should -Match '-strip'
        ($steps | Where-Object { $_.Name -eq 'DeflOpt (6/8)' } | Select-Object -First 1).Arguments | Should -Not -Match '/c'
    }

    It 'Disables GzipRecompress and preserves metadata flags when GZCopyMetadata is true' {
        $settings = Get-FoConfig
        $settings.GZCopyMetadata = $true
        $ctx = @{ Settings = $settings }

        $steps = Get-FoPipeline -GroupName GZIP -Context $ctx
        $active = @(Get-FoActiveSteps -Steps $steps -Context $ctx)

        @($active | Where-Object { $_.Name -like 'GzipRecompress*' }).Count | Should -Be 0
        ($steps | Where-Object { $_.Name -like 'ECT*' } | Select-Object -First 1).Arguments | Should -Not -Match '-strip'
        ($steps | Where-Object { $_.Name -eq 'DeflOpt (6/8)' } | Select-Object -First 1).Arguments | Should -Match '/c'
    }
}
