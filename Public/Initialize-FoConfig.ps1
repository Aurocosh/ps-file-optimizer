function Initialize-FoConfig {
    <#
    .SYNOPSIS
    Writes a default config PSD1 from the module template.

    .DESCRIPTION
    Copies Templates\Config.defaults.psd1 to the global config path or a local path,
    substituting default backup and plugin folder placeholders.

    .PARAMETER Scope
    Global — write to %USERPROFILE%\.config\FileOptimizer\config.psd1.
    Local — write to -Path (required).

    .PARAMETER Path
    Target file path when Scope is Local.

    .PARAMETER Force
    Overwrite an existing config file.

    .EXAMPLE
    Initialize-FoConfig -Scope Global

    .EXAMPLE
    .\Scripts\Optimize-File.ps1 -InitializeConfig Global
    #>
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
        $tempBackup = Join-Path $env:TEMP 'FileOptimizer\backups'
        $pluginPath = Get-FoDefaultPluginPath
        if (-not $pluginPath) {
            $folder = if ([Environment]::Is64BitProcess) { 'Plugins64' } else { 'Plugins32' }
            $pluginPath = Join-Path $script:FoModuleRoot $folder
        }
        $content = $content.Replace('__FO_TEMP_BACKUP__', $tempBackup)
        $content = $content.Replace('__FO_PLUGIN_PATH__', $pluginPath)
        Set-Content -LiteralPath $target -Value $content -Encoding UTF8
        Write-Host "Config written to: $target"
    }
}
