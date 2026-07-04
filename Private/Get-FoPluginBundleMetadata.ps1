# Plugin bundle metadata — default: ps-file-optimizer-aux GitHub Release (plain .7z).
# Legacy SourceForge SFX available via -UseLegacySourceForge on Install-FoPlugins.

$script:FoPluginBundleVersion = '1.0.0'
$script:FoPluginBundleUrl = 'https://github.com/Aurocosh/ps-file-optimizer-aux/releases/download/plugins-v1.0.0/fo-plugins-win-x64-1.0.0.7z'
$script:FoPluginBundleFileName = 'fo-plugins-win-x64-1.0.0.7z'
$script:FoPluginBundleSha256 = 'e314ad6ca1a435528fcc1a8c4737728c1d33bd8dd2197db7d36048ed65a1a5b8'
$script:FoPluginBundleFormat = '7z'

$script:FoPluginBundleLegacyUrl = 'https://sourceforge.net/projects/nikkhokkho/files/FileOptimizer/17.10.2857/FileOptimizerFull.7z.exe/download'
$script:FoPluginBundleLegacyFileName = 'FileOptimizerFull.7z.exe'
$script:FoPluginBundleLegacyFormat = 'sfx'

function Get-FoPluginBundleSettings {
    [CmdletBinding()]
    param(
        [string]$ArchiveUrl,
        [string]$ArchiveSha256,
        [switch]$UseLegacySourceForge
    )

    if ($env:FO_PLUGIN_BUNDLE_URL) {
        $fileName = if ($env:FO_PLUGIN_BUNDLE_FILENAME) {
            $env:FO_PLUGIN_BUNDLE_FILENAME
        }
        else {
            [System.IO.Path]::GetFileName(($env:FO_PLUGIN_BUNDLE_URL -split '\?')[0])
        }

        return [PSCustomObject]@{
            Url      = $env:FO_PLUGIN_BUNDLE_URL
            FileName = $fileName
            Sha256   = if ($env:FO_PLUGIN_BUNDLE_SHA256) { $env:FO_PLUGIN_BUNDLE_SHA256 } else { $ArchiveSha256 }
            Format   = if ($env:FO_PLUGIN_BUNDLE_FORMAT) { $env:FO_PLUGIN_BUNDLE_FORMAT } else { '7z' }
        }
    }

    if ($ArchiveUrl) {
        return [PSCustomObject]@{
            Url      = $ArchiveUrl
            FileName = [System.IO.Path]::GetFileName(($ArchiveUrl -split '\?')[0])
            Sha256   = $ArchiveSha256
            Format   = '7z'
        }
    }

    if ($UseLegacySourceForge) {
        return [PSCustomObject]@{
            Url      = $script:FoPluginBundleLegacyUrl
            FileName = $script:FoPluginBundleLegacyFileName
            Sha256   = $null
            Format   = $script:FoPluginBundleLegacyFormat
        }
    }

    return [PSCustomObject]@{
        Url      = $script:FoPluginBundleUrl
        FileName = $script:FoPluginBundleFileName
        Sha256   = $script:FoPluginBundleSha256
        Format   = $script:FoPluginBundleFormat
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
        [string]$ExtractRoot
    )

    $arch = if ([Environment]::Is64BitProcess) { 'Plugins64' } else { 'Plugins32' }
    $hit = Get-ChildItem -LiteralPath $ExtractRoot -Recurse -Directory -Filter $arch -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $hit) {
        throw "Could not find '$arch' directory inside extracted FileOptimizer archive."
    }
    return $hit.FullName
}
