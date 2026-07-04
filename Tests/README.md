# PS-FileOptimizer — Tests

Pester 5 test suite for the module. Requires [Pester](https://pester.dev/) 5.x (preinstalled on GitHub `ubuntu-latest` / `windows-latest` runners under pwsh).

## Quick start

```powershell
cd ps-file-optimizer
./Scripts/Invoke-FoTests.ps1
```

Run only fast unit tests (no plugin binaries, no network):

```powershell
./Scripts/Invoke-FoTests.ps1 -Tag Unit -ExcludeTag ImageIntegration,Lossy,Slow
```

Each `*.Tests.ps1` imports the **FoTestSupport** module in a `BeforeDiscovery` block. `Invoke-FoTests.ps1` preloads FoTestSupport so `-Skip:(-not (Test-FoPluginsAvailable))` on `Describe` blocks resolves correctly during discovery.

## Environment variables

| Variable | Purpose |
|----------|---------|
| `FO_TEST_PLUGIN_PATH` | Directory containing plugin executables (`magick.exe`, `oxipng.exe`, …). Used by image integration tests. When unset, tests fall back to `Get-FoDefaultPluginPath` (module `plugins\`, sibling `file-optimizer-full\Plugins64`, etc.). |
| `FO_TEST_CORPUS_PATH` | Root for downloaded image test tiers B–D (default: `Tests/Fixtures/Corpus/`). |
| `FO_RUN_INSTALL_INTEGRATION` | Set to `1` to enable network install integration tests (~76 MB aux release download). |
| `FO_RUN_CORPUS_INTEGRATION` | Set to `1` to enable Tier B corpus download integration test (~1 MB). |
| `FO_PLUGIN_BUNDLE_URL` | Override default plugin bundle download URL. |
| `FO_PLUGIN_BUNDLE_SHA256` | Expected SHA256 when using `FO_PLUGIN_BUNDLE_URL`. |

Example with plugins:

```powershell
$env:FO_TEST_PLUGIN_PATH = 'D:\Tools\FileOptimizerFull\Plugins64'
./Scripts/Invoke-FoTests.ps1 -Tag ImageIntegration
```

Plugin-dependent describes use `-Skip:(-not (Test-FoPluginsAvailable))` instead of failing the run.

## Pester tags

| Tag | When to use | CI unit job |
|-----|-------------|-------------|
| `Unit` | Config merge, helpers, corpus verify, bundle metadata | Included |
| `ImageIntegration` | Real optimize → compare loops; needs plugins | Excluded from PR unit job |
| `Integration` | Network download tests (plugins, corpus tiers B+) | Separate Windows job on push to `master` |
| `Lossy` | `*AllowLossy` settings profiles; SSIM thresholds | Excluded |
| `Slow` | Level 9, corpus sweeps, large fixtures | Excluded |

Recommended invocations:

```powershell
# Pull request — fast (matches CI unit job)
./Scripts/Invoke-FoTests.ps1 -Tag Unit -ExcludeTag ImageIntegration,Lossy,Slow

# With plugins — image integration
./Scripts/Invoke-FoTests.ps1 -Tag ImageIntegration

# Nightly — include lossy when plugins available
./Scripts/Invoke-FoTests.ps1 -ExcludeTag Slow

# Full suite
./Scripts/Invoke-FoTests.ps1
```

## CI

| Job | Runner | Command |
|-----|--------|---------|
| `unit` | `windows-latest` | `Invoke-FoTests.ps1 -Tag Unit -ExcludeTag ImageIntegration,Lossy,Slow` |
| `integration-downloads` | `windows-latest` (push to `master` only) | `Invoke-FoTests.ps1 -Tag Integration` with `FO_RUN_*=1` |

Both jobs use `shell: pwsh` (PowerShell 7), which loads Pester 5 without the legacy Windows PowerShell 5.1 Pester 3 conflict.

## Layout

| Path | Role |
|------|------|
| `FoTestSupport/` | Test support module (helpers, fixture paths, image orchestration) |
| `Scripts/Invoke-FoTests.ps1` | Single entry point for local runs and CI |
| `*.Tests.ps1` | Pester test files |
| `ImageTestManifest.psd1` | **FO-ImageTest-v1** corpus (Tier A + aux release metadata) |
| `ImageTestDecisions.psd1` | Thresholds and scope rules |
| `ImageTestProfiles.psd1` | Settings profiles (`LosslessDefault`, `LossyHighQuality`) |
| `Fixtures/Images/` | Tier A committed fixtures |

## Image verification decisions

Machine-readable thresholds live in `ImageTestDecisions.psd1` (loaded by FoTestSupport). Summary:

| Topic | Decision |
|-------|----------|
| JPEG (default profile) | Pixel compare via `magick compare -metric AE`; SSIM dissimilarity ≤ 0 fallback if AE > 0 |
| ICO | Compare **largest embedded icon** only |
| AVIF (default profile) | SSIM dissimilarity threshold (Tier C); calibrate in Phase 5 |
| Committed fixtures | Tier A: 34 files (~46 KB) under `Fixtures/Images/` |
