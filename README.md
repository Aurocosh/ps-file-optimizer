# PS-FileOptimizer

PowerShell module and CLI scripts that replicate [FileOptimizer](https://sourceforge.net/projects/nikkhokkho/files/FileOptimizer/) plugin chains with a proper command-line interface.

## Quick start

```powershell
Import-Module .\FileOptimizer.psd1

# Generate global config
Initialize-FoConfig -Scope Global

# Optimize files (default: TempMove — original backed up under %TEMP%\FileOptimizer\backups)
.\Scripts\Optimize-File.ps1 .\images\*.png

# Preview only
.\Scripts\Optimize-File.ps1 .\images\*.png -WhatIf

# View history
.\Scripts\Show-History.ps1 -Last 10

# Rollback last 3 optimizations
.\Scripts\Undo-Optimization.ps1 -Last 3

# Install all plugin binaries into .\plugins (downloads FileOptimizer bundle once)
.\Scripts\Install-Plugins.ps1 -Mode FullPortable

# Fill in only missing tools in an existing plugin folder
.\Scripts\Install-Plugins.ps1 -Mode Missing -PluginPath .\plugins
```

## Requirements

- Windows PowerShell 5.1+ or PowerShell 7+
- Plugin binaries from FileOptimizer portable (`FileOptimizerFull\Plugins64`), module `plugins\`, or tools on PATH
- `Install-FoPlugins` uses 7-Zip (`7z.exe`) or downloads `7zr.exe` temporarily to extract the bundle **without running** the FileOptimizer self-extractor

## Layout

| Path | Purpose |
|------|---------|
| `FileOptimizer.psd1` | Module manifest |
| `Public/` | Exported cmdlets |
| `Private/` | Engine, handlers, history |
| `Pipelines/` | Per-format plugin chains (39 groups) |
| `Data/ExtensionMap.psd1` | Extension → pipeline mapping |
| `Scripts/` | CLI entry points (`Install-Plugins.ps1` downloads FO bundle for portable plugins) |
| `plugins/` | Default target for `Install-FoPlugins` (gitignored if present) |

## Configuration

Precedence: module defaults → `%USERPROFILE%\.config\FileOptimizer\config.psd1` → `-ConfigPath` → explicit parameters.

See `Templates\Config.defaults.psd1` for available keys.

## Tests

```powershell
Invoke-Pester .\Tests\
```

See [`Tests/README.md`](Tests/README.md) for tags, environment variables, and image verification conventions.

### Unit tests (no plugins)

```powershell
Invoke-Pester .\Tests\ -Tag Unit -ExcludeTag ImageIntegration,Lossy,Slow
```

### Image integration tests

Require plugin binaries (`magick.exe` and format-specific tools). Point tests at your plugin folder:

```powershell
$env:FO_TEST_PLUGIN_PATH = 'D:\Tools\FileOptimizerFull\Plugins64'
Invoke-Pester .\Tests\ -Tag ImageIntegration
```

If plugins are missing, integration tests are marked **Inconclusive** rather than failed.

| Variable | Purpose |
|----------|---------|
| `FO_TEST_PLUGIN_PATH` | Plugin directory for integration tests (falls back to module `plugins\` or sibling `file-optimizer-full\Plugins64`) |
| `FO_RUN_INSTALL_INTEGRATION` | Set to `1` to run install download integration tests |

### Plugin install integration (network, ~110 MB download)

Validates `Install-FoPlugins` end-to-end: downloads the FileOptimizer bundle, extracts it without running the SFX, copies plugins, and cleans up temp files. Skipped unless enabled:

```powershell
$env:FO_RUN_INSTALL_INTEGRATION = '1'
Invoke-Pester .\Tests\Install-FoPlugins.Integration.Tests.ps1
```

Or run the manual smoke script:

```powershell
.\Tests\Smoke-Install-Plugins.ps1
```
