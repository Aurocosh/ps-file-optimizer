BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Test-FoPathMask' -Tag Unit {
    It 'Returns true when mask is empty or whitespace' {
        Test-FoPathMask -Path 'C:\data\photo.png' -Mask '' | Should -Be $true
        Test-FoPathMask -Path 'C:\data\photo.png' -Mask '   ' | Should -Be $true
    }

    It 'Matches when any comma-separated token appears in the path' {
        Test-FoPathMask -Path 'C:\work\images\photo.png' -Mask 'images,docs' | Should -Be $true
        Test-FoPathMask -Path 'C:\work\docs\readme.txt' -Mask 'images,docs' | Should -Be $true
    }

    It 'Does not match when no token appears in the path' {
        Test-FoPathMask -Path 'C:\work\audio\song.mp3' -Mask 'images,docs' | Should -Be $false
    }
}

Describe 'Test-FoFileGate masks' -Tag Unit {
    It 'Rejects paths outside IncludeMask' {
        $path = Join-Path $TestDrive 'outside.png'
        New-Item -ItemType File -Path $path -Force | Out-Null
        $settings = Get-FoConfig
        $settings.IncludeMask = 'allowed'

        $gate = Test-FoFileGate -Path $path -Settings $settings

        $gate.Pass | Should -Be $false
        $gate.Reason | Should -Be 'IncludeMask'
    }

    It 'Rejects paths matching ExcludeMask' {
        $path = Join-Path $TestDrive 'skip-me.png'
        New-Item -ItemType File -Path $path -Force | Out-Null
        $settings = Get-FoConfig
        $settings.ExcludeMask = 'skip-me'

        $gate = Test-FoFileGate -Path $path -Settings $settings

        $gate.Pass | Should -Be $false
        $gate.Reason | Should -Be 'ExcludeMask'
    }

    It 'Passes when include and exclude masks allow the path' {
        $path = Join-Path $TestDrive 'allowed\keep.png'
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        New-Item -ItemType File -Path $path -Force | Out-Null
        $settings = Get-FoConfig
        $settings.IncludeMask = 'allowed'
        $settings.ExcludeMask = 'quarantine'

        $gate = Test-FoFileGate -Path $path -Settings $settings

        $gate.Pass | Should -Be $true
    }
}

Describe 'Default-off text pipelines' -Tag Unit {
    It 'HTML pipeline has no active steps when HTMLEnableTidy is disabled' {
        $path = Join-Path $TestDrive 'sample.html'
        Set-Content -LiteralPath $path -Value '<html><body>test</body></html>' -Encoding UTF8
        $settings = Get-FoConfig
        $settings.HTMLEnableTidy = $false
        $ctx = New-FoFileContext -InputFile $path -Settings $settings

        @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName HTML -Context $ctx) -Context $ctx).Count |
            Should -Be 0
    }

    It 'CSS pipeline has no active steps when CSSEnableTidy is disabled' {
        $path = Join-Path $TestDrive 'sample.css'
        Set-Content -LiteralPath $path -Value 'body { color: red; }' -Encoding UTF8
        $settings = Get-FoConfig
        $settings.CSSEnableTidy = $false
        $ctx = New-FoFileContext -InputFile $path -Settings $settings

        @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName CSS -Context $ctx) -Context $ctx).Count |
            Should -Be 0
    }

    It 'JS pipeline has no active steps when JSEnableJSMin is disabled' {
        $path = Join-Path $TestDrive 'sample.js'
        Set-Content -LiteralPath $path -Value 'function x() { return 1; }' -Encoding UTF8
        $settings = Get-FoConfig
        $settings.JSEnableJSMin = $false
        $ctx = New-FoFileContext -InputFile $path -Settings $settings

        @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName JS -Context $ctx) -Context $ctx).Count |
            Should -Be 0
    }

    It 'XML pipeline has no active steps when XMLEnableLeanify is disabled' {
        $path = Join-Path $TestDrive 'sample.xml'
        Set-Content -LiteralPath $path -Value '<root><item/></root>' -Encoding UTF8
        $settings = Get-FoConfig
        $settings.XMLEnableLeanify = $false
        $ctx = New-FoFileContext -InputFile $path -Settings $settings

        @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName XML -Context $ctx) -Context $ctx).Count |
            Should -Be 0
    }

    It 'Lua pipeline has no active steps when LUAEnableLeanify is disabled' {
        $path = Join-Path $TestDrive 'sample.lua'
        Set-Content -LiteralPath $path -Value 'return 42' -Encoding UTF8
        $settings = Get-FoConfig
        $settings.LUAEnableLeanify = $false
        $ctx = New-FoFileContext -InputFile $path -Settings $settings

        @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName Lua -Context $ctx) -Context $ctx).Count |
            Should -Be 0
    }

    It 'HTML pipeline activates steps when HTMLEnableTidy is enabled' {
        $path = Join-Path $TestDrive 'enabled.html'
        Set-Content -LiteralPath $path -Value '<html></html>' -Encoding UTF8
        $settings = Get-FoConfig
        $settings.HTMLEnableTidy = $true
        $ctx = New-FoFileContext -InputFile $path -Settings $settings

        @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName HTML -Context $ctx) -Context $ctx).Count |
            Should -BeGreaterThan 0
    }
}

Describe 'Get-FoActiveSteps gate safety' -Tag Unit {
    It 'Skips steps when a gate scriptblock throws' {
        $step = [PSCustomObject]@{
            Gate = { throw 'boom' }
        }
        $ctx = @{
            Settings = @{ LogLevel = 0 }
        }

        $results = $null
        { $results = @(Get-FoActiveSteps -Steps @($step) -Context $ctx) } | Should -Not -Throw
        $results.Count | Should -Be 0
    }
}

Describe 'Invoke-FoPluginChain multi-group routing' -Tag Unit {
    It 'Includes all mapped pipeline groups on WhatIf results' {
        $db = Join-Path $TestDrive 'multi.db'
        Set-Content -LiteralPath $db -Value 'placeholder' -NoNewline

        $result = Invoke-FoPluginChain -Path $db -Settings (Get-FoConfig) -WhatIf

        $result.Status | Should -Be 'WhatIf'
        @($result.Groups) | Should -Be @('OLE', 'SQLite')
    }
}

Describe 'MiscDisable gating' -Tag Unit {
    It 'MISC pipeline has no active steps when MiscDisable is true' {
        $path = Join-Path $TestDrive 'sample.avs'
        Set-Content -LiteralPath $path -Value 'placeholder' -NoNewline
        $settings = Get-FoConfig
        $settings.MiscDisable = $true
        $ctx = New-FoFileContext -InputFile $path -Settings $settings

        @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName MISC -Context $ctx) -Context $ctx).Count |
            Should -Be 0
    }

    It 'MISC pipeline has active steps when MiscDisable is false' {
        $path = Join-Path $TestDrive 'sample.avs'
        Set-Content -LiteralPath $path -Value 'placeholder' -NoNewline
        $settings = Get-FoConfig
        $settings.MiscDisable = $false
        $ctx = New-FoFileContext -InputFile $path -Settings $settings

        @(Get-FoActiveSteps -Steps (Get-FoPipeline -GroupName MISC -Context $ctx) -Context $ctx).Count |
            Should -BeGreaterThan 0
    }

    It 'Multi-group routing still includes non-MISC groups when MiscDisable is true' {
        $path = Join-Path $TestDrive 'sample.epdf'
        Set-Content -LiteralPath $path -Value 'placeholder' -NoNewline
        $settings = Get-FoConfig
        $settings.MiscDisable = $true

        $plan = Get-FoExecutionPlan -Path $path -Settings $settings
        @($plan.Plans | Where-Object { $_.GroupName -eq 'MISC' } | ForEach-Object { $_.Steps.Count }) |
            Should -Be 0
        @($plan.Plans | Where-Object { $_.GroupName -eq 'PDF' } | ForEach-Object { $_.Steps.Count }) |
            Should -BeGreaterThan 0
    }
}

Describe 'Media metadata and lossy config toggles' -Tag Unit {
    It 'MP4 pipeline strips metadata by default' {
        $path = Join-Path $TestDrive 'sample.mp4'
        Set-Content -LiteralPath $path -Value 'placeholder' -NoNewline
        $settings = Get-FoConfig
        $ctx = New-FoFileContext -InputFile $path -Settings $settings
        $steps = @(Get-FoPipeline -GroupName MP4 -Context $ctx)

        $steps[0].Arguments | Should -Match '-map_metadata -1'
    }

    It 'MP4 pipeline keeps metadata when MP4CopyMetadata is true' {
        $path = Join-Path $TestDrive 'sample.mp4'
        Set-Content -LiteralPath $path -Value 'placeholder' -NoNewline
        $settings = Get-FoConfig
        $settings.MP4CopyMetadata = $true
        $ctx = New-FoFileContext -InputFile $path -Settings $settings
        $steps = @(Get-FoPipeline -GroupName MP4 -Context $ctx)

        $steps[0].Arguments | Should -Not -Match '-map_metadata -1'
    }

    It 'WebP pipeline defaults to lossless mode' {
        $path = Join-Path $TestDrive 'sample.webp'
        Set-Content -LiteralPath $path -Value 'placeholder' -NoNewline
        $settings = Get-FoConfig
        $ctx = New-FoFileContext -InputFile $path -Settings $settings
        $steps = @(Get-FoPipeline -GroupName WebP -Context $ctx)

        $steps[0].Arguments | Should -Match '-lossless'
        $steps[1].Arguments | Should -Match '-lossless'
    }

    It 'WebP pipeline enables lossy mode when WEBPAllowLossy is true' {
        $path = Join-Path $TestDrive 'sample.webp'
        Set-Content -LiteralPath $path -Value 'placeholder' -NoNewline
        $settings = Get-FoConfig
        $settings.WEBPAllowLossy = $true
        $ctx = New-FoFileContext -InputFile $path -Settings $settings
        $steps = @(Get-FoPipeline -GroupName WebP -Context $ctx)

        $steps[0].Arguments | Should -Match '-quality=95'
        $steps[1].Arguments | Should -Not -Match '-lossless'
    }
}

Describe 'Pipeline placeholder quoting' -Tag Unit {
    It 'PNG pngrewrite step uses bare placeholders in source template' {
        $png = Join-Path $PSScriptRoot 'Fixtures\Images\pngsuite\basn0g08.png'
        $ctx = New-FoFileContext -InputFile $png -Settings (Get-FoConfig)
        $step = @(Get-FoPipeline -GroupName PNG -Context $ctx) |
            Where-Object { $_.Name -like 'pngrewrite*' } |
            Select-Object -First 1

        $step | Should -Not -BeNullOrEmpty
        $step.Arguments | Should -Not -Match '"%(INPUT|TMPINPUT|TMPOUTPUT)FILE%"'
        $step.Arguments | Should -Match '%INPUTFILE%'
        $step.Arguments | Should -Match '%TMPOUTPUTFILE%'
    }
}
