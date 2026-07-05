# Plugin bundle metadata — ps-file-optimizer-aux GitHub Release (plain .zip).

$script:FoPluginBundleVersion = '1.0.0'
$script:FoPluginBundleReleaseTag = 'plugins-v1.0.0'
$script:FoPluginBundleFormat = 'zip'

$script:FoPluginBundles = @{
    '64' = @{
        Url      = 'https://github.com/Aurocosh/ps-file-optimizer-aux/releases/download/plugins-v1.0.0/fo-plugins-win-x64-1.0.0.zip'
        FileName = 'fo-plugins-win-x64-1.0.0.zip'
        Sha256   = '56e76bcd440cfd222ff2ad742524e81d1d323b944f02347da6f9398822e62901'
        Folder   = 'Plugins64'
    }
    '32' = @{
        Url      = 'https://github.com/Aurocosh/ps-file-optimizer-aux/releases/download/plugins-v1.0.0/fo-plugins-win-x86-1.0.0.zip'
        FileName = 'fo-plugins-win-x86-1.0.0.zip'
        Sha256   = 'd72772d9d20da14993eb213006432cd7903dce91d95e276114f2afda22d29894'
        Folder   = 'Plugins32'
    }
}

# Legacy single-bundle aliases (x64)
$script:FoPluginBundleUrl = $script:FoPluginBundles['64'].Url
$script:FoPluginBundleFileName = $script:FoPluginBundles['64'].FileName
$script:FoPluginBundleSha256 = $script:FoPluginBundles['64'].Sha256

function Resolve-FoPluginBundleArchitecture {
    [CmdletBinding()]
    param(
        [ValidateSet('Auto', '32', '64')]
        [string]$Architecture = 'Auto'
    )

    if ($Architecture -eq 'Auto') {
        if ([Environment]::Is64BitProcess) { return '64' }
        return '32'
    }

    return $Architecture
}

function Get-FoPluginBundleFolderName {
    [CmdletBinding()]
    param(
        [ValidateSet('32', '64')]
        [Parameter(Mandatory)]
        [string]$Architecture
    )

    if ($Architecture -eq '64') { return 'Plugins64' }
    return 'Plugins32'
}

function Get-FoPluginInstallRootPath {
    [CmdletBinding()]
    param(
        [string]$ModuleRoot = $script:FoModuleRoot
    )

    if (-not $ModuleRoot) { return $null }
    return [System.IO.Path]::GetFullPath($ModuleRoot)
}

function Get-FoInstalledPluginArchitecturePaths {
    [CmdletBinding()]
    param(
        [string]$ModuleRoot = $script:FoModuleRoot
    )

    $root = Get-FoPluginInstallRootPath -ModuleRoot $ModuleRoot
    if (-not $root) { return @() }

    $paths = @()
    foreach ($name in @('Plugins64', 'Plugins32', 'plugins')) {
        $candidate = Join-Path $root $name
        if (Test-Path -LiteralPath $candidate) {
            $paths += [PSCustomObject]@{
                Name = $name
                Path = $candidate
            }
        }
    }
    return $paths
}

function Remove-FoInstalledPluginArchitectures {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ModuleRoot = $script:FoModuleRoot,
        [ValidateSet('32', '64', 'All')]
        [string]$Scope = 'All',
        [string[]]$ExcludeFolderNames = @()
    )

    $root = Get-FoPluginInstallRootPath -ModuleRoot $ModuleRoot
    if (-not $root) { return @() }

    $targets = switch ($Scope) {
        'All' { @('Plugins64', 'Plugins32', 'plugins') }
        '64'  { @('Plugins32', 'plugins') }
        '32'  { @('Plugins64', 'plugins') }
    }

    $removed = @()
    foreach ($name in $targets) {
        if ($name -in $ExcludeFolderNames) { continue }
        $path = Join-Path $root $name
        if (-not (Test-Path -LiteralPath $path)) { continue }
        if ($PSCmdlet.ShouldProcess($path, 'Remove plugin directory')) {
            Remove-Item -LiteralPath $path -Recurse -Force
            $removed += $path
        }
    }
    return $removed
}

function Get-FoPluginBundleSettings {
    [CmdletBinding()]
    param(
        [ValidateSet('Auto', '32', '64')]
        [string]$Architecture = 'Auto',
        [string]$ArchiveUrl,
        [string]$ArchiveSha256
    )

    if ($env:FO_PLUGIN_BUNDLE_URL) {
        $fileName = if ($env:FO_PLUGIN_BUNDLE_FILENAME) {
            $env:FO_PLUGIN_BUNDLE_FILENAME
        }
        else {
            [System.IO.Path]::GetFileName(($env:FO_PLUGIN_BUNDLE_URL -split '\?')[0])
        }

        return [PSCustomObject]@{
            Architecture = Resolve-FoPluginBundleArchitecture -Architecture $(if ($env:FO_PLUGIN_BUNDLE_ARCH) { $env:FO_PLUGIN_BUNDLE_ARCH } else { $Architecture })
            Url          = $env:FO_PLUGIN_BUNDLE_URL
            FileName     = $fileName
            Sha256       = if ($env:FO_PLUGIN_BUNDLE_SHA256) { $env:FO_PLUGIN_BUNDLE_SHA256 } else { $ArchiveSha256 }
            Format       = if ($env:FO_PLUGIN_BUNDLE_FORMAT) { $env:FO_PLUGIN_BUNDLE_FORMAT } else { 'zip' }
            Folder       = if ($env:FO_PLUGIN_BUNDLE_FOLDER) { $env:FO_PLUGIN_BUNDLE_FOLDER } else { 'Plugins64' }
        }
    }

    if ($ArchiveUrl) {
        $arch = Resolve-FoPluginBundleArchitecture -Architecture $Architecture
        return [PSCustomObject]@{
            Architecture = $arch
            Url          = $ArchiveUrl
            FileName     = [System.IO.Path]::GetFileName(($ArchiveUrl -split '\?')[0])
            Sha256       = $ArchiveSha256
            Format       = 'zip'
            Folder       = Get-FoPluginBundleFolderName -Architecture $arch
        }
    }

    $resolvedArch = Resolve-FoPluginBundleArchitecture -Architecture $Architecture
    $entry = $script:FoPluginBundles[$resolvedArch]
    return [PSCustomObject]@{
        Architecture = $resolvedArch
        Url          = $entry.Url
        FileName     = $entry.FileName
        Sha256       = $entry.Sha256
        Format       = $script:FoPluginBundleFormat
        Folder       = $entry.Folder
    }
}

function Test-FoDownloadedFileSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$ExpectedSha256
    )

    if (-not $ExpectedSha256) {
        return
    }

    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $expected = $ExpectedSha256.ToLowerInvariant()
    if ($actual -ne $expected) {
        throw "Downloaded bundle SHA256 mismatch. Expected $expected, got $actual."
    }
}

# Ghostscript is chosen at runtime in PDF.ps1 via -Executable $gs (not a string literal).
function Get-FoGhostscriptExecutableName {
    if ([Environment]::Is64BitProcess) { return 'gswin64c.exe' }
    return 'gswin32c.exe'
}

function Get-FoRequiredPluginExecutables {
    [CmdletBinding()]
    param()

    $exes = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($handlerExes in $script:FoHandlerExecutables.Values) {
        foreach ($e in $handlerExes) {
            [void]$exes.Add($e)
        }
    }

    [void]$exes.Add((Get-FoGhostscriptExecutableName))

    $pipelineDir = Join-Path $script:FoModuleRoot 'Pipelines'
    Get-ChildItem -LiteralPath $pipelineDir -Filter '*.ps1' -File -ErrorAction Stop |
        Where-Object { $_.Name -ne '_Helpers.ps1' } |
        ForEach-Object {
            $content = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
            foreach ($m in [regex]::Matches($content, "-Executable\s+'([^']+)'")) {
                [void]$exes.Add($m.Groups[1].Value)
            }
        }

    return @($exes | Sort-Object)
}

function Test-FoPluginFilePresent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PluginPath,
        [Parameter(Mandatory)]
        [string]$FileName
    )

    if (-not $PluginPath -or -not (Test-Path -LiteralPath $PluginPath)) {
        return $false
    }

    $nameLower = $FileName.ToLowerInvariant()
    return [bool](
        Get-ChildItem -LiteralPath $PluginPath -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name.ToLowerInvariant() -eq $nameLower } |
            Select-Object -First 1
    )
}

function Get-FoPluginSupportFilesForExecutables {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Executables,
        [Parameter(Mandatory)]
        [string]$SourcePluginDir
    )

    $support = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $sourceFiles = @()
    if (Test-Path -LiteralPath $SourcePluginDir) {
        $sourceFiles = Get-ChildItem -LiteralPath $SourcePluginDir -File -ErrorAction SilentlyContinue
    }

    function Add-IfExists([string]$Name) {
        if ($sourceFiles | Where-Object { $_.Name -ieq $Name }) {
            [void]$support.Add($Name)
        }
    }

    function Add-Glob([string]$Pattern) {
        foreach ($f in ($sourceFiles | Where-Object { $_.Name -like $Pattern })) {
            [void]$support.Add($f.Name)
        }
    }

    foreach ($exe in $Executables) {
        switch -Regex ($exe) {
            '^flac\.exe$' {
                Add-IfExists 'libFLAC.dll'
            }
            '^gzip\.exe$' {
                Add-IfExists 'zlib.dll'
            }
            '^gswin64c\.exe$' {
                Add-IfExists 'gsdll64.dll'
            }
            '^gswin32c\.exe$' {
                Add-IfExists 'gsdll32.dll'
            }
            '^qpdf\.exe$' {
                Add-Glob 'qpdf*.dll'
            }
            '^m7zrepacker\.exe$' {
                Add-IfExists 'm7zRepacker.ini'
                Add-IfExists '7z.exe'
                Add-IfExists '7z.dll'
            }
            '^tidy\.exe$' {
                Add-IfExists 'tidy.config'
            }
            '^magick\.exe$' {
                foreach ($f in ($sourceFiles | Where-Object { $_.Extension -ieq '.dll' })) {
                    [void]$support.Add($f.Name)
                }
            }
            '^cwebp\.exe$' {
                Add-Glob 'libwebp*.dll'
                Add-Glob 'libsharpyuv*.dll'
            }
            '^mutool\.exe$' {
                Add-Glob 'mupdf*.dll'
            }
            '^strip\.exe$' {
                Add-Glob 'libwinpthread*.dll'
                Add-Glob 'libgcc*.dll'
                Add-Glob 'libstdc*.dll'
            }
        }
    }

    return @($support | Sort-Object)
}

function Get-FoPluginInstallFilePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Executables,
        [Parameter(Mandatory)]
        [string]$SourcePluginDir
    )

    $files = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($exe in $Executables) {
        [void]$files.Add($exe)
    }
    foreach ($f in (Get-FoPluginSupportFilesForExecutables -Executables $Executables -SourcePluginDir $SourcePluginDir)) {
        [void]$files.Add($f)
    }
    return @($files | Sort-Object)
}

function Get-FoMissingPluginExecutables {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PluginPath,
        [string[]]$RequiredExecutables
    )

    if (-not $RequiredExecutables) {
        $RequiredExecutables = Get-FoRequiredPluginExecutables
    }

    $missing = [System.Collections.Generic.List[string]]::new()
    foreach ($exe in $RequiredExecutables) {
        if (-not (Test-FoPluginFilePresent -PluginPath $PluginPath -FileName $exe)) {
            $missing.Add($exe)
        }
    }
    return @($missing)
}

function Resolve-FoBundledPluginDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ExtractRoot,
        [string]$ExpectedFolder
    )

    $candidates = @()
    if ($ExpectedFolder) {
        $candidates += Join-Path $ExtractRoot $ExpectedFolder
    }
    $candidates += @(
        $ExtractRoot
        (Join-Path $ExtractRoot 'plugins')
        (Join-Path $ExtractRoot 'Plugins64')
        (Join-Path $ExtractRoot 'Plugins32')
    )

    foreach ($dir in $candidates) {
        if (-not (Test-Path -LiteralPath $dir)) {
            continue
        }
        if (Test-FoPluginFilePresent -PluginPath $dir -FileName 'magick.exe') {
            return ([System.IO.Path]::GetFullPath($dir))
        }
    }

    throw "Could not find plugin executables in extracted bundle at '$ExtractRoot'."
}
