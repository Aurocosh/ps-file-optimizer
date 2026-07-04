# PS-FileOptimizer — Tests

Pester test suite for the module. Requires [Pester](https://pester.dev/) 3+ (5.x recommended).

## Quick start

```powershell
cd ps-file-optimizer
Invoke-Pester .\Tests\
```

Run only tests that do not need plugin binaries:

```powershell
Invoke-Pester .\Tests\ -Tag Unit -ExcludeTag ImageIntegration,Lossy,Slow
```

## Environment variables

| Variable | Purpose |
|----------|---------|
| `FO_TEST_PLUGIN_PATH` | Directory containing plugin executables (`magick.exe`, `oxipng.exe`, …). Used by image integration tests. When unset, tests fall back to `Get-FoDefaultPluginPath` (module `plugins\`, sibling `file-optimizer-full\Plugins64`, etc.). |
| `FO_RUN_INSTALL_INTEGRATION` | Set to `1` to enable network install integration tests (~110 MB download). |

Example:

```powershell
$env:FO_TEST_PLUGIN_PATH = 'D:\Tools\FileOptimizerFull\Plugins64'
Invoke-Pester .\Tests\ -Tag ImageIntegration
```

When plugins are not available, integration tests call `Set-TestInconclusive` — they do **not** fail the run.

## Pester tags

| Tag | When to use | CI (fast PR) |
|-----|-------------|--------------|
| `Unit` | Config merge, helpers, compare logic with mocked or generated files | Include |
| `ImageIntegration` | Real optimize → compare loops; needs `FO_TEST_PLUGIN_PATH` or auto-discovered plugins | Include if plugins present; inconclusive otherwise |
| `Lossy` | `*AllowLossy` settings profiles; SSIM thresholds | Exclude (run nightly or `-Tag Lossy`) |
| `Slow` | Level 9, corpus sweeps, large fixtures | Exclude |

Recommended CI invocations:

```powershell
# Pull request — fast
Invoke-Pester .\Tests\ -ExcludeTag Slow,Lossy

# Nightly — include lossy when plugins available
Invoke-Pester .\Tests\ -ExcludeTag Slow

# Weekly / release — full
Invoke-Pester .\Tests\
```

## Test files

| File | Tags | Notes |
|------|------|-------|
| `FileOptimizer.Tests.ps1` | (untagged / mixed) | Config, pipelines, history, install planning |
| `Compare-FoImage.Tests.ps1` | `Unit` | Phase 1 — image compare helper |
| `ImageOptimization.*.Tests.ps1` | `ImageIntegration` | Phase 3+ — per-format optimize + verify |
| `ImageOptimization.Lossy.Tests.ps1` | `ImageIntegration`, `Lossy` | Phase 5 |
| `Install-FoPlugins.Integration.Tests.ps1` | — | Requires `FO_RUN_INSTALL_INTEGRATION=1` |
| `Phase0.Foundations.Tests.ps1` | `Unit` | Plugin path discovery, decisions manifest |

## Image verification decisions

Machine-readable thresholds and scope rules live in `ImageTestDecisions.psd1` (loaded by `TestHelpers.ps1`). Summary:

| Topic | Decision |
|-------|----------|
| JPEG (default profile) | Pixel compare via `magick compare -metric AE`; SSIM ≥ 0.999 fallback if AE > 0 |
| ICO | Compare **largest embedded icon** only |
| AVIF (default profile) | SSIM ≥ 0.995 (Tier C); not pixel-identical gate |
| Python cross-check | Optional dev harness in Phase 7 only |
| Committed fixtures | Budget &lt; 500 KB total under `Fixtures/Images/` |

Full research: `file-optimizer-dev/ps-optimizer/docs/03-image-verification-testing.md`  
Implementation plan: `file-optimizer-dev/ps-optimizer/plans/01-image-testing-suite.md`

## Helpers

- `TestHelpers.ps1` — shared setup, `New-FoTestPng`, plugin discovery
- `ImageTestHelpers.ps1` — Phase 2+ optimize/compare orchestration
- `ImageTestProfiles.psd1` — Phase 2+ settings profiles (`LosslessDefault`, `LossyHighQuality`)
