function Initialize-FoConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Global', 'Local')]
        [string]$Scope,
        [string]$Path,
        [switch]$Force
    )

    $template = Join-Path $script:FoModuleRoot 'Templates\Config.defaults.psd1'
    if (-not (Test-Path -LiteralPath $template)) {
        throw "Config template not found: $template"
    }

    $target = if ($Scope -eq 'Global') {
        Get-FoGlobalConfigPath
    }
    else {
        if (-not $Path) { throw 'Local scope requires -Path.' }
        $Path
    }

    $target = [System.IO.Path]::GetFullPath($target)
    $dir = Split-Path -Parent $target
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        if ($PSCmdlet.ShouldProcess($dir, 'Create directory')) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    if ((Test-Path -LiteralPath $target) -and -not $Force) {
        throw "Config file already exists: $target. Use -Force to overwrite."
    }

    if ($PSCmdlet.ShouldProcess($target, 'Write config template')) {
        $content = Get-Content -LiteralPath $template -Raw -Encoding UTF8
        $content = $content -replace 'C:\\Users\\YOU', $env:USERPROFILE
        $content = $content -replace 'D:\\Tools\\FileOptimizerFull\\Plugins64', (Get-FoDefaultPluginPath)
        Set-Content -LiteralPath $target -Value $content -Encoding UTF8
        Write-Host "Config written to: $target"
    }
}
