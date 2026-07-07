BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'CLI script exit codes' -Tag Unit {
    BeforeAll {
        $script:FoCliModuleRoot = Split-Path -Parent $PSScriptRoot
    }

    It 'Optimize-File.ps1 exits 1 when no paths are specified' {
        $scriptPath = Join-Path $script:FoCliModuleRoot 'Scripts\Optimize-File.ps1'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath
        $LASTEXITCODE | Should -Be 1
    }

    It 'Optimize-File.ps1 exits 0 for -WhatIf on an existing file' {
        $file = Join-Path $TestDrive 'cli-whatif.png'
        [System.IO.File]::WriteAllBytes($file, [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0))
        $scriptPath = Join-Path $script:FoCliModuleRoot 'Scripts\Optimize-File.ps1'
        $command = "& '$scriptPath' '$($file.Replace("'", "''"))' -WhatIf"

        & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $command
        $LASTEXITCODE | Should -Be 0
    }

    It 'Undo-Optimization.ps1 exits 1 when neither -Path nor -Last is given' {
        $scriptPath = Join-Path $script:FoCliModuleRoot 'Scripts\Undo-Optimization.ps1'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath
        $LASTEXITCODE | Should -Be 1
    }

    It 'Install-Plugins.ps1 exits 0 for -WhatIf' {
        $scriptPath = Join-Path $script:FoCliModuleRoot 'Scripts\Install-Plugins.ps1'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath '-WhatIf' '-Mode' 'Remove'
        $LASTEXITCODE | Should -Be 0
    }
}
