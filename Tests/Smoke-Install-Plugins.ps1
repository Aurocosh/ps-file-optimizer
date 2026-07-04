# Manual smoke test for Install-FoPlugins (downloads ~76 MB aux release .7z).
# Exit code 0 on success, 1 on failure.

param(
    [string]$PluginPath
)

$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'FileOptimizer.psd1') -Force

$dest = if ($PluginPath) {
    $PluginPath
}
else {
    Join-Path $env:TEMP "FoSmokeInstall_$(Get-Random)"
}

Write-Host "Installing plugins to: $dest"
$result = Install-FoPlugins -Mode FullPortable -DestinationPath $dest

if (-not $result.Downloaded -or -not $result.Extracted) {
    Write-Error "Install failed: $($result.Message)"
}

$probe = Resolve-FoPluginExecutable -Name 'oxipng.exe' -SearchMode PortableOnly -PluginPath $dest
if (-not $probe.Found) {
    Write-Error 'oxipng.exe not found after install'
}

Write-Host "OK: copied $($result.FilesCopied.Count) file(s)."
Write-Host "Sample tool: $($probe.Path)"
exit 0
