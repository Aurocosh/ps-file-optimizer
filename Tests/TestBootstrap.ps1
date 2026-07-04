# Dot-source before Invoke-Pester on Pester 5 + PowerShell 7 (CI).
# Loads module and test helpers into the session scope so Describe/BeforeAll blocks can see them.
$script:FoTestRoot = $PSScriptRoot
$script:FoModuleRoot = Split-Path -Parent $FoTestRoot

Import-Module (Join-Path $FoModuleRoot 'FileOptimizer.psd1') -Force -ErrorAction Stop
. (Join-Path $FoTestRoot 'TestHelpers.ps1')
