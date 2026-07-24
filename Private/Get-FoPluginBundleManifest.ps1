$script:FoPluginBundleManifestFileName = 'fo-plugin-bundle.json'
$script:FoPluginBundleExcludePatterns = @('*.bat')

function Get-FoPluginBundleManifestFileName {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    return $script:FoPluginBundleManifestFileName
}

function Get-FoMinimumPluginBundleVersion {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    return $script:FoMinimumPluginBundleVersion
}

function Test-FoPluginBundleFileExcluded {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    foreach ($pattern in $script:FoPluginBundleExcludePatterns) {
        if ($FileName -like $pattern) { return $true }
    }
    if ($FileName -ieq $script:FoPluginBundleManifestFileName) { return $true }
    return $false
}

function Compare-FoPluginBundleVersion {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$Left,
        [Parameter(Mandatory)]
        [string]$Right
    )

    $leftVersion = [version]$Left
    $rightVersion = [version]$Right
    return $leftVersion.CompareTo($rightVersion)
}

function New-FoPluginBundleManifestObject {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$PluginDirectory,
        [Parameter(Mandatory)]
        [string]$BundleVersion,
        [Parameter(Mandatory)]
        [ValidateSet('32', '64')]
        [string]$Architecture,
        [string]$SourceBundleVersion,
        [datetime]$CreatedUtc = [datetime]::UtcNow
    )

    $folder = Get-FoPluginBundleFolderName -Architecture $Architecture
    $files = [System.Collections.Generic.List[object]]::new()

    Get-ChildItem -LiteralPath $PluginDirectory -File -ErrorAction Stop |
        Where-Object { -not (Test-FoPluginBundleFileExcluded -FileName $_.Name) } |
        Sort-Object Name |
        ForEach-Object {
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $files.Add(@{
                Path   = $_.Name
                Sha256 = $hash
                Size   = [int64]$_.Length
            })
        }

    $manifest = @{
        SchemaVersion = 1
        BundleVersion = $BundleVersion
        Architecture  = $Architecture
        Folder        = $folder
        CreatedUtc    = $CreatedUtc.ToString('o')
        Files         = @($files)
    }
    if ($SourceBundleVersion) {
        $manifest.SourceBundleVersion = $SourceBundleVersion
    }
    return $manifest
}

function Save-FoPluginBundleManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest,
        [Parameter(Mandatory)]
        [string]$Path
    )

    Save-FoJsonFile -Path $Path -Data $Manifest -Depth 8
}

function Import-FoPluginBundleManifest {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $data = Import-FoJsonFile -Path $Path
    if (-not $data.BundleVersion) {
        throw "Plugin bundle manifest is missing BundleVersion: $Path"
    }
    if (-not $data.Files) {
        throw "Plugin bundle manifest is missing Files: $Path"
    }
    return $data
}

function Get-FoInstalledPluginBundleInfo {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$PluginPath
    )

    if (-not $PluginPath -or -not (Test-Path -LiteralPath $PluginPath)) {
        return [PSCustomObject]@{
            Found         = $false
            Path          = $null
            BundleVersion = $null
            Architecture  = $null
            Manifest      = $null
            Error         = if ($PluginPath) { 'PluginPath not found' } else { 'PluginPath not set' }
        }
    }

    $manifestPath = Join-Path $PluginPath $script:FoPluginBundleManifestFileName
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        return [PSCustomObject]@{
            Found         = $false
            Path          = $manifestPath
            BundleVersion = $null
            Architecture  = $null
            Manifest      = $null
            Error         = 'Manifest not found'
        }
    }

    try {
        $manifest = Import-FoPluginBundleManifest -Path $manifestPath
        return [PSCustomObject]@{
            Found         = $true
            Path          = $manifestPath
            BundleVersion = [string]$manifest.BundleVersion
            Architecture  = [string]$manifest.Architecture
            Manifest      = $manifest
            Error         = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            Found         = $false
            Path          = $manifestPath
            BundleVersion = $null
            Architecture  = $null
            Manifest      = $null
            Error         = $_.Exception.Message
        }
    }
}

function Test-FoPluginBundleManifestFiles {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest,
        [Parameter(Mandatory)]
        [string]$PluginDirectory
    )

    $mismatched = [System.Collections.Generic.List[string]]::new()
    $missing = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in @($Manifest.Files)) {
        $rel = [string]$entry.Path
        $full = Join-Path $PluginDirectory $rel
        if (-not (Test-Path -LiteralPath $full)) {
            $missing.Add($rel)
            continue
        }
        $actual = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
        $expected = ([string]$entry.Sha256).ToLowerInvariant()
        if ($actual -ne $expected) {
            $mismatched.Add($rel)
        }
    }

    return [PSCustomObject]@{
        Ok          = ($missing.Count -eq 0 -and $mismatched.Count -eq 0)
        Missing     = @($missing)
        Mismatched  = @($mismatched)
    }
}

function Find-FoPluginBundleManifestPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ExtractRoot
    )

    $direct = Join-Path $ExtractRoot $script:FoPluginBundleManifestFileName
    if (Test-Path -LiteralPath $direct) {
        return ([System.IO.Path]::GetFullPath($direct))
    }

    foreach ($dir in @(Get-ChildItem -LiteralPath $ExtractRoot -Directory -ErrorAction SilentlyContinue)) {
        $candidate = Join-Path $dir.FullName $script:FoPluginBundleManifestFileName
        if (Test-Path -LiteralPath $candidate) {
            return ([System.IO.Path]::GetFullPath($candidate))
        }
    }

    return $null
}

function Set-FoAcknowledgedPluginBundleMinimum {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$MinimumVersion,
        [string]$ConfigPath
    )

    $path = if ($ConfigPath) {
        $ConfigPath
    }
    else {
        Get-FoGlobalConfigPath
    }

    $data = @{}
    if (Test-Path -LiteralPath $path) {
        $data = Import-FoJsonFile -Path $path
        if ($null -eq $data) { $data = @{} }
    }

    if ($PSCmdlet.ShouldProcess($path, "Set AcknowledgedPluginBundleMinimum=$MinimumVersion")) {
        $data['AcknowledgedPluginBundleMinimum'] = $MinimumVersion
        Save-FoJsonFile -Path $path -Data $data -Depth 10
    }
}

function Test-FoPluginDirectoryHasBinaries {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$PluginPath
    )

    if (-not $PluginPath -or -not (Test-Path -LiteralPath $PluginPath)) {
        return $false
    }

    return [bool](
        Get-ChildItem -LiteralPath $PluginPath -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -ine $script:FoPluginBundleManifestFileName -and
                ($_.Extension -ieq '.exe' -or $_.Extension -ieq '.dll')
            } |
            Select-Object -First 1
    )
}

function Assert-FoPluginBundleVersionForOptimize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Settings
    )

    $minimum = Get-FoMinimumPluginBundleVersion
    if (-not $minimum) { return }

    # No plugin binaries installed yet — let missing-tools handling report that.
    if (-not (Test-FoPluginDirectoryHasBinaries -PluginPath $Settings.PluginPath)) {
        return
    }

    $info = Get-FoInstalledPluginBundleInfo -PluginPath $Settings.PluginPath
    $installed = if ($info.Found -and $info.BundleVersion) {
        [string]$info.BundleVersion
    }
    else {
        '0.0.0'
    }

    if ((Compare-FoPluginBundleVersion -Left $installed -Right $minimum) -ge 0) {
        return
    }

    $ack = [string]$Settings.AcknowledgedPluginBundleMinimum
    if ($ack -and ((Compare-FoPluginBundleVersion -Left $ack -Right $minimum) -ge 0)) {
        Write-Warning ("Installed plugin bundle version '{0}' is below required minimum '{1}' (acknowledgment recorded). Run Install-FoPlugins to upgrade." -f $installed, $minimum)
        return
    }

    $detail = if ($info.Error) { " ($($info.Error))" } else { '' }
    throw ("Installed plugin bundle version '{0}' is below required minimum '{1}'{2}. Run Install-FoPlugins to upgrade, or pass -AcknowledgeOutdatedPlugins to continue with a warning until the next required plugin-bundle upgrade." -f $installed, $minimum, $detail)
}
