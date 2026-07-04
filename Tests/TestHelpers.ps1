if ($global:FoTestSupportLoaded) { return }

$global:FoTestSupportRoot = $PSScriptRoot
$global:FoTestModuleRoot = Split-Path -Parent $PSScriptRoot
$global:FoModuleRoot = $global:FoTestModuleRoot

foreach ($name in @(
    'Import-FoDataFile'
    'Get-FoModuleDefaults'
    'Format-FoFileSize'
    'Merge-FoSettings'
    'Get-ExtensionByContent'
    'Test-FoFileGate'
    'Invoke-FoOutputMode'
    'Add-FoHistoryEntry'
    'Format-FoHistoryEntry'
)) {
    . (Join-Path $global:FoTestModuleRoot "Private\$name.ps1")
}

. (Join-Path $global:FoTestModuleRoot 'Public\Resolve-FoPluginExecutable.ps1')
. (Join-Path $global:FoTestModuleRoot 'Private\Compare-FoImage.ps1')
. (Join-Path $global:FoTestModuleRoot 'Private\Get-FoImageInfo.ps1')
. (Join-Path $PSScriptRoot 'ImageTestHelpers.ps1')

$global:FoImageTestDecisions = Import-FoDataFile -Path (Join-Path $PSScriptRoot 'ImageTestDecisions.psd1')
$global:FoTestSupportLoaded = $true

function Get-FoImageTestDecisions {
    return $global:FoImageTestDecisions
}

function Get-FoTestPluginPath {
    if ($env:FO_TEST_PLUGIN_PATH) {
        $candidate = $env:FO_TEST_PLUGIN_PATH.Trim()
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return ([System.IO.Path]::GetFullPath($candidate))
        }
        return $null
    }

    $default = Get-FoDefaultPluginPath
    if ($default) { return $default }

    $modulePlugins = Join-Path $global:FoModuleRoot 'plugins'
    if (Test-Path -LiteralPath $modulePlugins) {
        return ([System.IO.Path]::GetFullPath($modulePlugins))
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

function Assert-FoPluginsAvailable {
    param(
        [string]$Reason = 'Plugin binaries not found. Set FO_TEST_PLUGIN_PATH or install plugins via Install-FoPlugins.'
    )

    if (-not (Test-FoPluginsAvailable)) {
        Set-TestInconclusive $Reason
    }
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
