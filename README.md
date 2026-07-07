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

# Install all plugin binaries into .\Plugins64 (64-bit PS) or .\Plugins32 (32-bit PS)
.\Scripts\Install-Plugins.ps1 -Mode FullPortable

# Remove installed plugin folders (Plugins64, Plugins32, legacy plugins/)
.\Scripts\Install-Plugins.ps1 -Mode Remove

# Force 32-bit bundle on 64-bit PowerShell
.\Scripts\Install-Plugins.ps1 -Mode FullPortable -Architecture 32

# Download Tier B image test corpus for nightly integration (optional)
.\Scripts\Get-ImageTestCorpus.ps1 -Tier B

# Fill in only missing tools in an existing plugin folder
.\Scripts\Install-Plugins.ps1 -Mode Missing -PluginPath .\Plugins64
```

## Requirements

- Windows PowerShell 5.1+ or PowerShell 7+
- Plugin binaries from the [ps-file-optimizer-aux](https://github.com/Aurocosh/ps-file-optimizer-aux) release bundle (default), module `Plugins64\` / `Plugins32\`, or tools on PATH
- `Install-FoPlugins` downloads a plain `.zip` archive (~107 MB x64, ~83 MB x86), verifies SHA256, and extracts with `Expand-Archive`. Only one architecture folder exists under the module root at a time.

### 32-bit PowerShell limitations

When you install/use `Plugins32\` (x86), several x64-only tools are intentionally absent from the bundle:

- `minify.exe` (affects JS/CSS/HTML minification chain depth)
- `optivorbis.exe` (affects OGG optimization depth)
- `tinydng-cli.exe` (affects DNG optimization support)

Related pipelines automatically skip missing steps when these tools are unavailable, so optimization still runs but may produce fewer size wins than `Plugins64\`.

## Layout

| Path | Purpose |
|------|---------|
| `FileOptimizer.psd1` | Module manifest |
| `Public/` | Exported cmdlets |
| `Private/` | Engine, handlers, history |
| `Pipelines/` | Per-format plugin chains (39 groups) |
| `Data/ExtensionMap.psd1` | Extension → pipeline mapping |
| `Scripts/` | CLI entry points (`Install-Plugins.ps1` downloads plugin bundle from aux release) |
| `plugins/` | Legacy flat plugin dir (removed when switching architecture; gitignored if present) |
| `Plugins64/` | Default install target on 64-bit PowerShell (gitignored if present) |
| `Plugins32/` | Default install target on 32-bit PowerShell (gitignored if present) |
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
$env:FO_TEST_PLUGIN_PATH = Join-Path $PWD 'Plugins64'
./Scripts/Invoke-FoTests.ps1 -Tag ImageIntegration
```

If plugins are missing, integration describes are **Skipped** rather than failed.

| Variable | Purpose |
|----------|---------|
| `FO_PLUGIN_PATH` | Default plugin directory when set (overrides module `Plugins64\` / `Plugins32\` for normal runs) |
| `FO_TEST_PLUGIN_PATH` | Plugin directory for integration tests (falls back to `FO_PLUGIN_PATH` or module plugin folders) |
| `FO_TEST_CORPUS_PATH` | Root for downloaded image test tiers B–D (default: `Tests/Fixtures/Corpus/`) |
| `FO_RUN_INSTALL_INTEGRATION` | Set to `1` to run install download integration tests |
| `FO_RUN_CORPUS_INTEGRATION` | Set to `1` to run Tier B corpus download integration test |

### Plugin install integration (network, ~195 MB total for x64 + x86 zip)

Validates `Install-FoPlugins` end-to-end: downloads the aux release `.zip`, verifies SHA256, extracts, copies plugins, and cleans up temp files. Skipped unless enabled:

```powershell
$env:FO_RUN_INSTALL_INTEGRATION = '1'
./Scripts/Invoke-FoTests.ps1 -Tag Integration
```

Override bundle URL for mirrors or pre-release testing:

```powershell
$env:FO_PLUGIN_BUNDLE_URL = 'https://github.com/Aurocosh/ps-file-optimizer-aux/releases/download/plugins-v1.0.0/fo-plugins-win-x64-1.0.0.zip'
$env:FO_PLUGIN_BUNDLE_SHA256 = 'd2889306b31c3bb8b356e2d6de0d5f893f26e2e334812c0e541b9c0fe65a04a0'
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
$env:FO_TEST_PLUGIN_PATH = Join-Path $PWD 'Plugins64'
./Scripts/Invoke-FoImageCorpusSweep.ps1 -Tier A
```

### Pipeline step debugger (image corruption)

When an image integration test fails, bisect the pipeline to find which step first breaks visual compare:

```powershell
$env:FO_TEST_PLUGIN_PATH = Join-Path $PWD 'Plugins64'
./Scripts/Debug-FoPipelineSteps.ps1 .\Tests\Fixtures\Images\pngsuite\basn2c08.png
./Scripts/Debug-FoPipelineSteps.ps1 .\photo.jpg -ProfileName LossyHighQuality
```

The script compares against an untouched copy after each step, writes per-step snapshots and diff PNGs under a work directory, and reports the first failing step.
