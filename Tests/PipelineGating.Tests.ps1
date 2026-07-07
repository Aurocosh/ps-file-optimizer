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
