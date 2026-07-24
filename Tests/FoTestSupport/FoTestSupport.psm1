$script:FoTestSupportRoot = Split-Path -Parent $PSScriptRoot
$script:FoModuleRoot = Split-Path -Parent $script:FoTestSupportRoot

Import-Module (Join-Path $script:FoModuleRoot 'FileOptimizer.psd1') -Force

. (Join-Path $script:FoModuleRoot 'Private\_Import-FoEngine.ps1')
foreach ($name in (Get-FoTestSupportPrivateScriptNames)) {
    . (Join-Path $script:FoModuleRoot "Private\$name.ps1")
}

. (Join-Path $script:FoModuleRoot 'Public\Resolve-FoPluginExecutable.ps1')
. (Join-Path $PSScriptRoot 'Private\Get-FoImageInfo.ps1')
. (Join-Path $PSScriptRoot 'Private\Compare-FoImage.ps1')
. (Join-Path $script:FoModuleRoot 'Private\Get-FoPluginBundleMetadata.ps1')
. (Join-Path $script:FoModuleRoot 'Private\Get-FoPluginBundleManifest.ps1')
. (Join-Path $script:FoModuleRoot 'Private\Install-FoPluginBundle.ps1')
. (Join-Path $script:FoModuleRoot 'Private\Get-FoDssimBundleMetadata.ps1')
. (Join-Path $script:FoModuleRoot 'Private\Install-FoDssimBundle.ps1')
. (Join-Path $script:FoModuleRoot 'Private\Handlers\Invoke-FoNativeHandlers.ps1')
. (Join-Path $script:FoModuleRoot 'Private\Get-FoStepRequiredExecutables.ps1')
. (Join-Path $script:FoModuleRoot 'Private\Invoke-FoPlugin.ps1')
. (Join-Path $script:FoModuleRoot 'Pipelines\_Helpers.ps1')
Get-ChildItem -Path (Join-Path $script:FoModuleRoot 'Pipelines\*.ps1') -Exclude '_Helpers.ps1' | ForEach-Object { . $_.FullName }
. (Join-Path $script:FoModuleRoot 'Public\Get-FoPipeline.ps1')
. (Join-Path $PSScriptRoot 'Private\ImageTestSupport.ps1')

$script:FoImageTestDecisions = Import-FoPsd1File -Path (Join-Path $script:FoTestSupportRoot 'ImageTestDecisions.psd1')

function Get-FoTestSupportRoot {
    return $script:FoTestSupportRoot
}

function Get-FoTestModuleRoot {
    return $script:FoModuleRoot
}

function Get-FoImageTestDecisions {
    return $script:FoImageTestDecisions
}

function Get-FoImageTestFixtureRoot {
    return Join-Path $script:FoTestSupportRoot 'Fixtures\Images'
}

function Get-FoTestPluginPath {
    if ($env:FO_TEST_PLUGIN_PATH) {
        $candidate = $env:FO_TEST_PLUGIN_PATH.Trim()
        if ($candidate) {
            $resolved = Resolve-FoTestPluginPathCandidate -Candidate $candidate -ModuleRoot $script:FoModuleRoot
            if ($resolved) { return $resolved }
        }
        return $null
    }

    $default = Get-FoDefaultPluginPath
    if ($default) { return $default }

    return $null
}

function Resolve-FoTestPluginPathCandidate {
    param(
        [Parameter(Mandatory)]
        [string]$Candidate,
        [string]$ModuleRoot
    )

    if ([System.IO.Path]::IsPathRooted($Candidate)) {
        if (Test-Path -LiteralPath $Candidate) {
            return ([System.IO.Path]::GetFullPath($Candidate))
        }
        return $null
    }

    if (Test-Path -LiteralPath $Candidate) {
        return ([System.IO.Path]::GetFullPath($Candidate))
    }

    if ($ModuleRoot) {
        $fromModule = Join-Path $ModuleRoot $Candidate
        if (Test-Path -LiteralPath $fromModule) {
            return ([System.IO.Path]::GetFullPath($fromModule))
        }
    }

    return $null
}

function Test-FoPluginsAvailable {
    [CmdletBinding()]
    param(
        [string[]]$RequiredExecutables = @('magick.exe')
    )

    $pluginPath = Get-FoTestPluginPath
    if (-not $pluginPath) { return $false }

    foreach ($exe in $RequiredExecutables) {
        $resolved = Resolve-FoPluginExecutable -Name $exe -SearchMode PortableOnly -PluginPath $pluginPath
        if (-not $resolved.Found) { return $false }
    }

    return $true
}

function New-FoTestPng {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [int]$Width = 1,
        [int]$Height = 1,
        [string]$MagickPath
    )

    if ($Width -eq 1 -and $Height -eq 1) {
        [byte[]]$bytes = 0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A,0x00,0x00,0x00,0x0D,0x49,0x48,0x44,0x52,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x01,0x08,0x06,0x00,0x00,0x00,0x1F,0x15,0xC4,0x89,0x00,0x00,0x00,0x0A,0x49,0x44,0x41,0x54,0x78,0x9C,0x63,0x00,0x01,0x00,0x00,0x05,0x00,0x01,0x0D,0x0A,0x2D,0xB4,0x00,0x00,0x00,0x00,0x49,0x45,0x4E,0x44,0xAE,0x42,0x60,0x82
        [System.IO.File]::WriteAllBytes($Path, $bytes)
        return
    }

    if (-not (Test-FoPluginsAvailable -RequiredExecutables @('magick.exe'))) {
        throw 'magick.exe is required to generate PNG fixtures larger than 1x1.'
    }

    $magick = if ($MagickPath) { $MagickPath } else {
        (Resolve-FoPluginExecutable -Name 'magick.exe' -SearchMode PortableFirst -PluginPath (Get-FoTestPluginPath)).Path
    }
    $workDir = Split-Path -Parent $magick
    $sizeArg = "${Width}x${Height}"

    $result = Invoke-FoMagickCli -MagickExe $magick -WorkingDirectory $workDir -ArgumentList @(
        '-size', $sizeArg
        'xc:#4080c0'
        "PNG24:$Path"
    )

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $Path)) {
        throw "Failed to generate test PNG at '$Path': $($result.StdErr)"
    }
}

function Test-FoImageOptimizationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Result,
        [switch]$RequireCompare,
        [switch]$RequireSizeReduction
    )

    if (@('Optimized', 'Unchanged') -notcontains $Result.Optimization.Status) {
        return $false
    }

    if ($RequireSizeReduction -and $Result.Optimization.Status -eq 'Optimized') {
        if ($Result.Optimization.FinalSize -ge $Result.Optimization.OriginalSize) {
            return $false
        }
    }

    if ($Result.Decode) {
        if ($Result.Decode.Width -le 0 -or $Result.Decode.Height -le 0) {
            return $false
        }
    }

    if ($RequireCompare) {
        if (-not $Result.Compare -or -not $Result.Compare.Pass -or -not $Result.Pass) {
            return $false
        }
    }

    return $true
}

function Test-FoLossyOptimizationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Result,
        [double]$SSIMDissimilarityMaximum
    )

    if (@('Optimized', 'Unchanged') -notcontains $Result.Optimization.Status) {
        return $false
    }

    if ($Result.Optimization.Status -eq 'Optimized') {
        if ($Result.Optimization.FinalSize -gt $Result.Optimization.OriginalSize) {
            return $false
        }
    }

    if ($Result.CompareMode -ne 'SSIMOnly') {
        return $false
    }

    if (-not $Result.Compare -or -not $Result.Compare.Pass) {
        return $false
    }

    if ($Result.Compare.MetricValue -gt $SSIMDissimilarityMaximum) {
        return $false
    }

    return $Result.Pass
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

$script:FoTestSupportFunctions = @(
    'Get-FoTestSupportRoot'
    'Get-FoTestModuleRoot'
    'Get-FoModuleDefaults'
    'Get-FoImageTestDecisions'
    'Get-FoImageTestFixtureRoot'
    'Get-FoTestPluginPath'
    'Test-FoPluginsAvailable'
    'New-FoTestPng'
    'Import-FoPsd1File'
    'Import-FoJsonFile'
    'Format-FoFileSize'
    'Format-FoProcessArgument'
    'Merge-FoSettings'
    'Test-FoSafeSuffix'
    'Invoke-FoOutputMode'
    'Add-FoHistoryEntry'
    'New-FoFileContext'
    'Test-FoPathMask'
    'Test-FoFileGate'
    'Get-ExtensionByContent'
    'Get-FoPipelineGroupsForFile'
    'Get-FoActiveSteps'
    'Resolve-FoPluginExecutable'
    'Compare-FoImage'
    'Get-FoImageInfo'
    'Invoke-FoMagickCli'
    'Get-FoImageTestCorpusRoot'
    'Get-FoImageTestManifest'
    'Get-FoImageTestFixtureEntry'
    'Get-FoImageTestFixturePath'
    'Test-FoImageTestFixturesPresent'
    'Get-FoImageTestArtifactPaths'
    'Get-FoImageTestProfile'
    'Get-FoImageTestProfileCompareMode'
    'Resolve-FoImageTestLossyFormat'
    'Get-FoImageTestLossyFixtureOverride'
    'Copy-FoImageFixture'
    'Invoke-FoImageOptimizationTest'
    'Get-FoImageTestLossyThreshold'
    'Invoke-FoLossyImageOptimizationTest'
    'Test-FoImageOptimizationResult'
    'Test-FoLossyOptimizationResult'
    'Get-FoGifFrameCount'
    'Compare-FoGifFrames'
    'Test-FoJpegImageCompare'
    'Get-FoFfmpegPath'
    'Get-FoApngFrameCount'
    'Compare-FoApngFrames'
    'Get-FoIcoEmbeddedEntries'
    'Get-FoIcoLargestIndex'
    'Compare-FoIcoLargest'
    'Get-FoPluginBundleSettings'
    'Resolve-FoPluginBundleArchitecture'
    'Resolve-FoPluginArchitectureFromPath'
    'Get-FoGhostscriptExecutableName'
    'Remove-FoInstalledPluginArchitectures'
    'Get-FoPluginBundleManifestFileName'
    'Get-FoMinimumPluginBundleVersion'
    'Compare-FoPluginBundleVersion'
    'New-FoPluginBundleManifestObject'
    'Save-FoPluginBundleManifest'
    'Import-FoPluginBundleManifest'
    'Get-FoInstalledPluginBundleInfo'
    'Test-FoPluginBundleManifestFiles'
    'Find-FoPluginBundleManifestPath'
    'Set-FoAcknowledgedPluginBundleMinimum'
    'Assert-FoPluginBundleInstalled'
    'Assert-FoPluginBundleVersionForOptimize'
    'Test-FoPluginDirectoryHasBinaries'
    'Get-FoDssimBundleSettings'
    'Test-FoDssimCompareAvailable'
    'Test-FoCompareAllowMissingDssim'
    'Test-FoCompareDssimRequiredError'
    'Assert-FoDssimCompareAvailable'
    'Test-FoDownloadedFileSha256'
    'Invoke-FoPluginBundleDownload'
    'Write-FoTestPluginVersions'
    'Test-FoPluginInstallIntegrationCore'
)

$script:FoTestSupportEngineFunctions = @(
    'Get-FoExecutionPlan'
    'Invoke-FoPlugin'
    'Invoke-FoGzipRecompress'
    'Invoke-FoJsMinPipe'
    'Invoke-FoDefluffPipe'
)

$fileOptimizerFunctions = @(
    'Optimize-FoFile'
    'Get-FoPipeline'
    'Invoke-FoPluginChain'
    'Get-FoConfig'
    'Initialize-FoConfig'
    'Undo-FoOptimization'
    'Get-FoHistory'
    'Install-FoPlugins'
    'Install-FoDssim'
)
Export-ModuleMember -Function ($script:FoTestSupportFunctions + $script:FoTestSupportEngineFunctions + $fileOptimizerFunctions)
