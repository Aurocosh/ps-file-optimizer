# FileOptimizer 17.10.2857 portable bundle (see file-optimizer-dev docs/ps-optimizer/02-external-tools.md)
$script:FoPluginBundleUrl = 'https://sourceforge.net/projects/nikkhokkho/files/FileOptimizer/17.10.2857/FileOptimizerFull.7z.exe/download'
$script:FoPluginBundleFileName = 'FileOptimizerFull.7z.exe'

# Ghostscript is chosen at runtime in PDF.ps1 via -Executable $gs (not a string literal).
$script:FoPluginExecutableSupplements = @(
    'gswin64c.exe'
    'gswin32c.exe'
)

function Get-FoRequiredPluginExecutables {
    [CmdletBinding()]
    param()

    $exes = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($handlerExes in $script:FoHandlerExecutables.Values) {
        foreach ($e in $handlerExes) {
            [void]$exes.Add($e)
        }
    }

    foreach ($e in $script:FoPluginExecutableSupplements) {
        [void]$exes.Add($e)
    }

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
