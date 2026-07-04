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
| `FO_TEST_PLUGIN_PATH` | Directory containing plugin executables (`magick.exe`, `oxipng.exe`, …). Used by image integration tests. When unset, tests fall back to `Get-FoDefaultPluginPath` (module `plugins\` or `FO_PLUGIN_PATH`). |
| `FO_TEST_CORPUS_PATH` | Root for downloaded image test tiers B–D (default: `Tests/Fixtures/Corpus/`). |
| `FO_RUN_INSTALL_INTEGRATION` | Set to `1` to enable network install integration tests (~76 MB aux release download). |
| `FO_RUN_CORPUS_INTEGRATION` | Set to `1` to enable Tier B corpus download integration test (~1 MB). |
| `FO_PLUGIN_BUNDLE_URL` | Override default plugin bundle download URL. |
| `FO_PLUGIN_BUNDLE_SHA256` | Expected SHA256 when using `FO_PLUGIN_BUNDLE_URL`. |

Example with plugins:

```powershell
$env:FO_TEST_PLUGIN_PATH = Join-Path $PWD 'plugins'
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
| `Scripts/Invoke-FoImageCorpusSweep.ps1` | L3 batch optimize + CSV metrics (Slow; needs plugins) |
| `*.Tests.ps1` | Pester test files |
| `ImageTestManifest.psd1` | **FO-ImageTest-v1** corpus (Tier A + aux release metadata) |
| `ImageTestDecisions.psd1` | SSIM compare thresholds (JPEG fallback, AVIF default) |
| `ImageTestProfiles.psd1` | Settings profiles (`LosslessDefault`, `LossyHighQuality`) |
| `Fixtures/Images/` | Tier A committed fixtures |

## Image compare thresholds

`ImageTestDecisions.psd1` holds SSIM thresholds consumed by FoTestSupport:

| Key | Used by |
|-----|---------|
| `JpegSSIMFallbackMaximum` | `Test-FoJpegImageCompare` when pixel (AE) compare fails |
| `AvifDefaultSSIMDissimilarityMaximum` | AVIF integration tests (`LosslessDefault` profile) |

Lossy format ceilings live in `ImageTestProfiles.psd1` (`LossyHighQuality.SSIMDissimilarityMaximum`). ICO tests compare the largest embedded icon via `Compare-FoIcoLargest` (see `ImageOptimization.Ico.Tests.ps1`).

## Failure artifacts

`Invoke-FoImageOptimizationTest` always sets a default compare diff path under `{WorkDirectory}/artifacts/diffs/`. When a test fails (compare, decode, or optimization status), it writes:

| Artifact | Path |
|----------|------|
| Compare diff PNG | `artifacts/diffs/{name}_diff.png` (when compare fails) |
| `magick identify -verbose` | `artifacts/identify/{name}_before.txt`, `{name}_after.txt` |
| Optimization log | `artifacts/optimization.txt` (status, sizes, step log, metric) |

The result object includes `FailureArtifacts` with paths. Pester leaves artifacts under `$TestDrive` for failed integration tests.

## Corpus sweep (L3 regression)

Batch-optimize many fixtures and export CSV metrics (tagged **Slow** — not part of PR CI):

```powershell
$env:FO_TEST_PLUGIN_PATH = Join-Path $PWD 'plugins'
./Scripts/Invoke-FoImageCorpusSweep.ps1 -Tier A -ProfileName LosslessDefault
./Scripts/Get-ImageTestCorpus.ps1 -Tier B
./Scripts/Invoke-FoImageCorpusSweep.ps1 -Tier B -MaxFiles 50 -OutputCsv .\tier-b.csv
```

Use `-SkipCompare` for size-only regression runs. Plugin versions are logged to verbose output at the start of `Invoke-FoTests.ps1` and corpus sweeps.
