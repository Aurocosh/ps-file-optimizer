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
| `FO_TEST_PLUGIN_PATH` | Directory containing plugin executables (`magick.exe`, `oxipng.exe`, …). Used by image integration tests. When unset, tests fall back to `Get-FoDefaultPluginPath` (`Plugins64\` / `Plugins32\` or `FO_PLUGIN_PATH`). |
| `FO_TEST_CORPUS_PATH` | Root for downloaded image test tiers B–D (default: `Tests/Fixtures/Corpus/`). |
| `FO_RUN_INSTALL_INTEGRATION` | Set to `1` to enable network install integration tests (~110 MB x64 + ~85 MB x86 aux zip downloads). |
| `FO_RUN_CORPUS_INTEGRATION` | Set to `1` to enable Tier B corpus download integration test (~1 MB). |
| `FO_PLUGIN_BUNDLE_URL` | Override default plugin bundle download URL. |
| `FO_PLUGIN_BUNDLE_SHA256` | Expected SHA256 when using `FO_PLUGIN_BUNDLE_URL`. |
| `FO_PLUGIN_BUNDLE_CACHE_DIR` | CI/local cache root for downloaded bundle zips (keyed by SHA256 subfolder). |
| `FO_DSSIM_BUNDLE_URL` | Override default DSSIM zip download URL (compare tool for PNG tests). |
| `FO_DSSIM_BUNDLE_SHA256` | Expected SHA256 when using `FO_DSSIM_BUNDLE_URL`. |
| `FO_COMPARE_ALLOW_MISSING_DSSIM` | Set to `1` to allow PNG pixel compare without dssim (ImageMagick AE fallback). |
| `FO_TEST_ARTIFACT_DIR` | When set (CI image-smoke), image tests write compare failure artifacts here for upload. |

Example with plugins:

```powershell
$env:FO_TEST_PLUGIN_PATH = Join-Path $PWD 'Plugins64'
./Scripts/Invoke-FoTests.ps1 -Tag ImageIntegration
```

Plugin-dependent describes use `-Skip:(-not (Test-FoPluginsAvailable))` instead of failing the run.

## Pester tags

| Tag | When to use | CI unit job |
|-----|-------------|-------------|
| `Unit` | Config merge, helpers, corpus verify, bundle metadata | Included |
| `Smoke` | Fast image optimize+compare (PNG/BMP/GIF); needs cached plugins | `image-smoke` job only |
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

| Job | Runner | Trigger | Command |
|-----|--------|---------|---------|
| `unit` | `windows-latest` | push / PR to `master` | `Invoke-FoTests.ps1 -Tag Unit -ExcludeTag ImageIntegration,Lossy,Slow` |
| `image-smoke` | `windows-latest` | push / PR to `master` | Restore plugin cache (`actions/cache` on `FoPlugins64` + dssim); install bundle on miss; `FO_TEST_PLUGIN_PATH` → `Invoke-FoTests.ps1 -Tag Smoke` |
| `integration-downloads` | `windows-latest` | push to `master` only | `FO_RUN_INSTALL_INTEGRATION=1`, `FO_RUN_CORPUS_INTEGRATION=1`, `FO_PLUGIN_BUNDLE_CACHE_DIR` → `Invoke-FoTests.ps1 -Tag Integration` (x64 + x86 plugin install) |

All jobs use `shell: pwsh` (PowerShell 7). The `image-smoke` and `integration-downloads` jobs cache downloaded bundle archives under `FO_PLUGIN_BUNDLE_CACHE_DIR` (see workflow SHA256 comment keys in `.github/workflows/ci.yml`). On `image-smoke` failure, compare artifacts under `FO_TEST_ARTIFACT_DIR` are uploaded via `actions/upload-artifact`.

## Layout

| Path | Role |
|------|------|
| `FoTestSupport/` | Test support module (helpers, fixture paths, image orchestration) |
| `Scripts/Invoke-FoTests.ps1` | Single entry point for local runs and CI |
| `Scripts/Invoke-FoImageCorpusSweep.ps1` | L3 batch optimize + CSV metrics (Slow; needs plugins) |
| `Scripts/Debug-FoPipelineSteps.ps1` | Step-by-step pipeline bisect when image compare fails (needs plugins) |
| `Scripts/Install-Dssim.ps1` | Download pinned dssim 3.4.0 for PNG compare (test-only; 64-bit) |
| `*.Tests.ps1` | Pester test files |
| `ImageTestManifest.psd1` | **FO-ImageTest-v1** corpus (Tier A + aux release metadata) |
| `ImageTestDecisions.psd1` | Compare thresholds (JPEG fallback, AVIF default, PNG DSSIM) |
| `ImageTestProfiles.psd1` | Settings profiles (`LosslessDefault`, `LossyHighQuality`) including preferred `CompareMode` per profile |
| `ImageTestLossyOverrides.psd1` | Per-path SSIM ceilings for LossyHighQuality corpus sweeps (Tier B outliers) |
| `Fixtures/Images/` | Tier A committed fixtures |

## Image compare thresholds

`ImageTestDecisions.psd1` holds compare thresholds consumed by FoTestSupport:

| Key | Used by |
|-----|---------|
| `JpegSSIMFallbackMaximum` | `Test-FoJpegImageCompare` when pixel (AE) compare fails |
| `AvifDefaultSSIMDissimilarityMaximum` | AVIF integration tests (`LosslessDefault` profile) |
| `PngDssimDissimilarityMaximum` | PNG pixel compare via [dssim](https://github.com/kornelski/dssim) when `{PluginPath}/dssim/dssim.exe` is present (default `0` = identical) |

Lossy format ceilings live in `ImageTestProfiles.psd1` (`LossyHighQuality.SSIMDissimilarityMaximum`). For PNG, `PNGMicro` applies when min(width,height) ≤ 64. Tier A manifest entries and `ImageTestLossyOverrides.psd1` supply per-path `LossySSIMMaximum` for known outliers (palette pngquant, gb82-sc graph, JPEG conformance edge cases). Corpus sweeps map `.jpg` → `JPEG` for threshold lookup. ICO tests compare the largest embedded icon via `Compare-FoIcoLargest` (see `ImageOptimization.Ico.Tests.ps1`).

## Tiered image compare (`Compare-FoImage`)

Lossless verification uses a **format-aware tier** rather than a single ImageMagick path:

| Format / case | Engine | Notes |
|---------------|--------|-------|
| **PNG** (both paths `.png`) | **dssim 3.4.0** (required by default) | `{PluginPath}/dssim/dssim.exe`; 64-bit only. Throws if missing unless `-AllowMissingDssim` or `FO_COMPARE_ALLOW_MISSING_DSSIM=1`. |
| **BMP / DIB** | magick normalize, with **ffmpeg → imagew** fallbacks | ImageMagick cannot decode some FO BMP variants; ffmpeg handles most; imagew covers 2-bit palette and ffmpeg disagreements. |
| **Other lossless** (GIF frame, WebP lossless, TIFF, …) | magick normalize + **AE** (Pixel mode) | Same as Phase 1 design. |
| **Lossy profiles** | magick **SSIM** dissimilarity | JPEG may fall back to SSIM when AE fails; AVIF/WebP lossy use profile ceilings. |

Install dssim for PNG compare (required for corpus sweeps and PNG integration tests on 64-bit):

```powershell
./Scripts/Install-Dssim.ps1
```

To allow ImageMagick AE fallback when dssim is absent (not recommended for pngsuite/regression):

```powershell
./Scripts/Invoke-FoImageCorpusSweep.ps1 -Tier B -AllowMissingDssim
# or: $env:FO_COMPARE_ALLOW_MISSING_DSSIM = '1'
```

Pinned release: `dssim-3.4.0.zip` from [kornelski/dssim releases](https://github.com/kornelski/dssim/releases) — only `win/dssim.exe` is copied to `{PluginPath}/dssim/dssim.exe` (AGPL-3.0). Skipped automatically on 32-bit PowerShell.

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
$env:FO_TEST_PLUGIN_PATH = Join-Path $PWD 'Plugins64'
./Scripts/Invoke-FoImageCorpusSweep.ps1 -Tier A -ProfileName LosslessDefault
./Scripts/Invoke-FoImageCorpusSweep.ps1 -Tier A -ProfileName LossyHighQuality
./Scripts/Get-ImageTestCorpus.ps1 -Tier B
./Scripts/Invoke-FoImageCorpusSweep.ps1 -Tier B -MaxFiles 50 -OutputCsv .\tier-b.csv
```

Each profile in `ImageTestProfiles.psd1` declares a preferred `CompareMode` (`Pixel` for lossless, `SSIMOnly` for lossy). The sweep uses that unless you pass `-CompareMode` explicitly.

Use `-SkipCompare` for size-only regression runs. Default CSV name: `corpus-sweep-tier{tier}-{profile}-{timestamp}.csv` (e.g. `corpus-sweep-tiera-LosslessDefault-20260705-180000.csv`). Each row includes `OptimizeDurationMs` (plugin chain) and `CompareDurationMs` (visual compare; empty when `-SkipCompare` or optimization failed).

Plugin versions are logged to verbose output at the start of `Invoke-FoTests.ps1` and corpus sweeps.

Per-file compare or optimization errors are recorded in the CSV `Error` column; the sweep continues through the full corpus unless the error is a missing-dssim prerequisite (fails fast at sweep start or rethrows per file). **BMP** pixel compare uses bundled `ffmpeg.exe` (RGBA PNG) when ImageMagick normalize fails, and falls back to `imagew.exe` when ffmpeg cannot decode (e.g. 2-bit palette BMP) or when ffmpeg-normalized pixels still disagree (e.g. 4-bit palette v4 layouts). **PNG** pixel compare requires **dssim** under `{PluginPath}/dssim/dssim.exe` (64-bit) unless opted out. Motion-JPEG fixtures (e.g. `mjpeg.jpg`) can hang ImageMagick during normalize-for-compare; `Invoke-FoMagickCli` enforces a 90s timeout so the sweep records a compare error instead of blocking indefinitely.
