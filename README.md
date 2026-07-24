# PS-FileOptimizer

PowerShell module and CLI scripts that replicate [FileOptimizer](https://sourceforge.net/projects/nikkhokkho/files/FileOptimizer/) plugin chains with a proper command-line interface.

## License

This project’s source code is licensed under the [GNU Affero General Public License v3.0](LICENSE).

Third-party plugin binaries and optional test tools have **their own licenses** and are not covered by this project’s AGPL. See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and the aux repo [`PLUGIN-CREDITS.md`](https://github.com/Aurocosh/ps-file-optimizer-aux/blob/master/PLUGIN-CREDITS.md).

## Release notes

See [`RELEASE_NOTES.md`](RELEASE_NOTES.md) for the version index, and [`ReleaseNotes/`](ReleaseNotes/) for per-version notes.

## Quick start

```powershell
Import-Module .\FileOptimizer.psd1

# Generate global config
Initialize-FoConfig -Scope Global

# Optimize files (default: TempMove — original backed up under %TEMP%\FileOptimizer\backups)
.\Scripts\Optimize-File.ps1 .\images\*.png

# Quoted wildcards also work when calling the cmdlet directly
Optimize-FoFile -Path '.\images\*.png'

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
- Plugin bundle credits are listed in [`ps-file-optimizer-aux/PLUGIN-CREDITS.md`](https://github.com/Aurocosh/ps-file-optimizer-aux/blob/master/PLUGIN-CREDITS.md).

### 32-bit PowerShell limitations

When you install/use `Plugins32\` (x86), several x64-only tools are intentionally absent from the bundle:

- `minify.exe` (affects JS/CSS/HTML minification chain depth)
- `optivorbis.exe` (affects OGG optimization depth)
- `tinydng-cli.exe` (affects DNG optimization support)

Related pipelines automatically skip missing steps when these tools are unavailable, so optimization still runs but may produce fewer size wins than `Plugins64\`.

## Pipelines

The module defines **39 format groups** under `Pipelines/`. Most map 1:1 from file extension via `Data/ExtensionMap.psd1`.

**MISC catch-all:** Unrecognized image-like extensions route to the `MISC` pipeline, which runs ImageMagick `convert` optimization. This can alter pixels or metadata in ways that are hard to predict. Leave `MiscDisable = false` only when you explicitly want that behavior; set `MiscDisable = true` in `config.json` (or pass via a local config file with `-ConfigPath`) to skip the MISC group entirely.

## Layout

| Path | Purpose |
|------|---------|
| `FileOptimizer.psd1` | Module manifest |
| `RELEASE_NOTES.md` | Index of per-version release notes |
| `ReleaseNotes/` | Release notes markdown files named `{ModuleVersion}.md` |
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

Precedence: module defaults → `%USERPROFILE%\.config\FileOptimizer\config.json` → `-ConfigPath` → explicit parameters.

See `Templates\Config.defaults.json` for available keys.

Notable media options: `MP4CopyMetadata` keeps container metadata for MP4/MKV/OGV pipelines when set to `true`; `WEBPAllowLossy` enables lossy WebP optimization steps.

When a required plugin tool is missing, `MissingToolsPolicy` controls behavior:

| Value | Behavior |
|-------|----------|
| `Error` (default) | Fail the file with a hard error |
| `SkipTool` | Skip steps that need missing tools; continue other steps |
| `SkipFile` | Skip the entire file if any required tool is missing |

If the portable plugin bundle is not installed at all (`Install-FoPlugins` never run), optimization fails with install instructions (unless `PluginSearchMode` is `PathOnly`).

Use `-ContinueOnError` on `Optimize-FoFile` (or `Optimize-File.ps1`) to finish a multi-file batch after individual file failures.

## History and undo

When `HistoryEnabled` is true (default), each successful optimization appends an entry to `history.json` (beside your config, or `HistoryPath`).

| Field | Meaning |
|-------|---------|
| `TargetPath` | User-visible path where the optimized file was written (undo restore destination) |
| `OriginalPath` | Same value as `TargetPath` on each entry |
| `OptimizedPath` | Optimized output path (same as `TargetPath` for in-place modes; sibling file for `OptimizedSuffix`) |
| `BackupPath` | Pre-optimization bytes for reversible modes (`TempMove`, `BackupSuffix`, `BackupMove`) |
| `ReversalStatus` | `Pending`, `Reversed`, `NotReversible`, or `Error` |

Reversible output modes: `TempMove`, `BackupSuffix`, `BackupMove`, `OptimizedSuffix`. `Replace` is not reversible.

```json
{
  "Version": 1,
  "Entries": [
    {
      "Id": "20260708-143000-001",
      "Timestamp": "2026-07-08T14:30:00",
      "TargetPath": "C:\\data\\photo.png",
      "OriginalPath": "C:\\data\\photo.png",
      "OptimizedPath": "C:\\data\\photo.png",
      "BackupPath": "C:\\Users\\you\\AppData\\Local\\Temp\\FileOptimizer\\backups\\photo.png",
      "OutputMode": "TempMove",
      "OriginalSize": 120000,
      "FinalSize": 95000,
      "ReversalStatus": "Pending"
    }
  ]
}
```

```powershell
Get-FoHistory -Last 10
Undo-FoOptimization -Last 3
```

Module overview: `Get-Help about_FileOptimizer -Full`

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

### DSSIM compare tool (test only)

`Install-FoDssim` (exported cmdlet) and `Scripts/Install-Dssim.ps1` download pinned [dssim](https://github.com/kornelski/dssim) 3.4.0 for **PNG pixel comparison in image tests** (`Compare-FoImage`, corpus sweeps, CI smoke). **Not required for file optimization** — no optimization pipeline invokes dssim.

```powershell
./Scripts/Install-Dssim.ps1 -PluginPath .\Plugins64
# or: Install-FoDssim -DestinationPath .\Plugins64
```

See [`Tests/README.md`](Tests/README.md) for compare thresholds and `FO_COMPARE_ALLOW_MISSING_DSSIM`.

| Variable | Purpose |
|----------|---------|
| `FO_PLUGIN_PATH` | Default plugin directory when set (overrides module `Plugins64\` / `Plugins32\` for normal runs) |
| `FO_TEST_PLUGIN_PATH` | Plugin directory for integration tests (falls back to `FO_PLUGIN_PATH` or module plugin folders) |
| `FO_TEST_CORPUS_PATH` | Root for downloaded image test tiers B–D (default: `Tests/Fixtures/Corpus/`) |
| `FO_RUN_INSTALL_INTEGRATION` | Set to `1` to run install download integration tests |
| `FO_RUN_CORPUS_INTEGRATION` | Set to `1` to run Tier B corpus download integration test |

### Plugin install integration (network, ~195 MB total for x64 + x86 zip)

Validates `Install-FoPlugins` end-to-end: downloads the [ps-file-optimizer-aux](https://github.com/Aurocosh/ps-file-optimizer-aux) release `.zip`, verifies SHA256, extracts, copies plugins, and cleans up temp files. Skipped unless enabled:

```powershell
$env:FO_RUN_INSTALL_INTEGRATION = '1'
./Scripts/Invoke-FoTests.ps1 -Tag Integration
```

Override bundle URL for mirrors or pre-release testing:

```powershell
$env:FO_PLUGIN_BUNDLE_URL = 'https://github.com/Aurocosh/ps-file-optimizer-aux/releases/download/plugins-v1.1.0/fo-plugins-win-x64-1.1.0.zip'
$env:FO_PLUGIN_BUNDLE_SHA256 = '64cbf3ab2c8bd2dbd097b77286dd439d19f9c37f9fadbc1420ccefcd968847b2'
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
