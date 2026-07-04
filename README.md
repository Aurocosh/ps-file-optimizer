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

# Install all plugin binaries into .\plugins (downloads aux release bundle once)
.\Scripts\Install-Plugins.ps1 -Mode FullPortable

# Download Tier B image test corpus for nightly integration (optional)
.\Scripts\Get-ImageTestCorpus.ps1 -Tier B

# Fill in only missing tools in an existing plugin folder
.\Scripts\Install-Plugins.ps1 -Mode Missing -PluginPath .\plugins
```

## Requirements

- Windows PowerShell 5.1+ or PowerShell 7+
- Plugin binaries from the [ps-file-optimizer-aux](https://github.com/Aurocosh/ps-file-optimizer-aux) release bundle (default), module `plugins\`, or tools on PATH
- `Install-FoPlugins` downloads a plain `.7z` archive (~76 MB), verifies SHA256, and extracts with 7-Zip (`7z.exe`) or a temporary `7zr.exe` bootstrap

## Layout

| Path | Purpose |
|------|---------|
| `FileOptimizer.psd1` | Module manifest |
| `Public/` | Exported cmdlets |
| `Private/` | Engine, handlers, history |
| `Pipelines/` | Per-format plugin chains (39 groups) |
| `Data/ExtensionMap.psd1` | Extension → pipeline mapping |
| `Scripts/` | CLI entry points (`Install-Plugins.ps1` downloads plugin bundle from aux release) |
| `plugins/` | Default target for `Install-FoPlugins` (gitignored if present) |
| `Tests/Fixtures/Corpus/` | Downloaded image test tiers B–D (gitignored); Tier A under `Fixtures/Images/` |

## Configuration

Precedence: module defaults → `%USERPROFILE%\.config\FileOptimizer\config.psd1` → `-ConfigPath` → explicit parameters.

See `Templates\Config.defaults.psd1` for available keys.

## Tests

```powershell
./Scripts/Invoke-FoTests.ps1
```

See [`Tests/README.md`](Tests/README.md) for tags, environment variables, and image verification conventions.

### Unit tests (no plugins)

```powershell
./Scripts/Invoke-FoTests.ps1 -Tag Unit -ExcludeTag ImageIntegration,Lossy,Slow
```

### Image integration tests

Require plugin binaries (`magick.exe` and format-specific tools). Point tests at your plugin folder:

```powershell
$env:FO_TEST_PLUGIN_PATH = Join-Path $PWD 'plugins'
./Scripts/Invoke-FoTests.ps1 -Tag ImageIntegration
```

If plugins are missing, integration describes are **Skipped** rather than failed.

| Variable | Purpose |
|----------|---------|
| `FO_TEST_PLUGIN_PATH` | Plugin directory for integration tests (falls back to module `plugins\` or sibling `file-optimizer-full\Plugins64`) |
| `FO_TEST_CORPUS_PATH` | Root for downloaded image test tiers B–D (default: `Tests/Fixtures/Corpus/`) |
| `FO_RUN_INSTALL_INTEGRATION` | Set to `1` to run install download integration tests |
| `FO_RUN_CORPUS_INTEGRATION` | Set to `1` to run Tier B corpus download integration test |

### Plugin install integration (network, ~76 MB download)

Validates `Install-FoPlugins` end-to-end: downloads the aux release `.7z`, verifies SHA256, extracts, copies plugins, and cleans up temp files. Skipped unless enabled:

```powershell
$env:FO_RUN_INSTALL_INTEGRATION = '1'
./Scripts/Invoke-FoTests.ps1 -Tag Integration
```

Override bundle URL for mirrors or pre-release testing:

```powershell
$env:FO_PLUGIN_BUNDLE_URL = 'https://github.com/Aurocosh/ps-file-optimizer-aux/releases/download/plugins-v1.0.0/fo-plugins-win-x64-1.0.0.7z'
$env:FO_PLUGIN_BUNDLE_SHA256 = 'e314ad6ca1a435528fcc1a8c4737728c1d33bd8dd2197db7d36048ed65a1a5b8'
```

Or run the manual smoke script:

```powershell
.\Tests\Smoke-Install-Plugins.ps1
```

### Image test corpus (optional download)

Tier **A** fixtures are committed under `Tests/Fixtures/Images/`. Tiers **B–D** download from the [ps-file-optimizer-aux](https://github.com/Aurocosh/ps-file-optimizer-aux) `image-test-v1` release:

```powershell
.\Scripts\Get-ImageTestCorpus.ps1 -Tier A   # verify committed fixtures
.\Scripts\Get-ImageTestCorpus.ps1 -Tier B   # standard integration set (~1 MB)
.\Scripts\Get-ImageTestCorpus.ps1 -Tier C   # GB82 photographic (~9.5 MB)
.\Scripts\Get-ImageTestCorpus.ps1 -Tier D   # calibration subset (~4 MB)
```

Corpus integration test (network):

```powershell
$env:FO_RUN_CORPUS_INTEGRATION = '1'
./Scripts/Invoke-FoTests.ps1 -Tag Integration
```

Corpus sweep (batch optimize + CSV metrics; requires plugins):

```powershell
$env:FO_TEST_PLUGIN_PATH = Join-Path $PWD 'plugins'
./Scripts/Invoke-FoImageCorpusSweep.ps1 -Tier A
```
