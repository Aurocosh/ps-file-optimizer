# Image test fixtures — FO-ImageTest-v1 Tier A

34 files (~46 KB) vendored from [imazen/codec-corpus](https://github.com/imazen/codec-corpus) @ `bb1da434fd3ab9ef58577f505d2f9194123e5d6e`.

Directory layout matches upstream paths (e.g. `pngsuite/basn0g01.png`).

## Verify

```powershell
cd ps-file-optimizer
.\Scripts\Get-ImageTestCorpus.ps1 -Tier A
```

## Regenerate (maintainers)

Copy paths listed under `Tiers.A.Files` in `Tests/ImageTestManifest.psd1` from a local codec-corpus clone, then refresh `MANIFEST.sha256`. Tier B–D release zips: `file-optimizer-dev/ps-optimizer/scripts/Build-ImageTestRelease.ps1`.

## Manifest

- Machine-readable list: `Tests/ImageTestManifest.psd1`
- SHA256 checksums: `MANIFEST.sha256`
- Full specification: `file-optimizer-dev/ps-optimizer/docs/04-test-image-dataset.md`

## Licenses (summary)

| Folder | License |
|--------|---------|
| `pngsuite/` | Freeware ([PNGsuite](http://www.schaik.com/pngsuite/)) |
| `gif-conformance/`, `apng-conformance/` | CC0 |
| `mozjpeg/`, `jpeg-conformance/` | IJG + BSD / per-file |
| `webp-conformance/` | RFC test vectors |
| `bmp-conformance/` | Various |
| `image-rs/` | MIT |

Tier B+ corpora download to `Tests/Fixtures/Corpus/tier-{b,c,d}/` (gitignored) via `Scripts/Get-ImageTestCorpus.ps1` from the ps-file-optimizer-aux `image-test-v1` release.
