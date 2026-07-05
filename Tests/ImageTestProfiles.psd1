@{
    LosslessDefault = @{
        CompareMode    = 'Pixel'
        PNGAllowLossy  = $false
        JPEGAllowLossy = $false
        GIFAllowLossy  = $false
        WEBPAllowLossy = $false
        Level          = 5
        OutputMode     = 'Replace'
        HistoryEnabled = $false
    }
    LossyHighQuality = @{
        CompareMode    = 'SSIMOnly'
        PNGAllowLossy  = $true
        JPEGAllowLossy = $true
        GIFAllowLossy  = $true
        WEBPAllowLossy = $true
        Level          = 9
        OutputMode     = 'Replace'
        HistoryEnabled = $false
        # SSIM dissimilarity ceilings (0 = identical). Calibrated 2026-07 on Tier A/B/C with bundled plugins.
        # PNG: 256x256 generated ~0.01; gb82 photographic (Tier C) up to ~0.018 at L9.
        # PNGMicro: pngsuite 32x32 and smaller at L9 up to ~0.76.
        # JPEG photos ~0.005; conformance edge cases in ImageTestLossyOverrides.psd1.
        SSIMDissimilarityMaximum = @{
            Default  = 0.02
            JPEG     = 0.02
            PNG      = 0.02
            PNGMicro = 0.8
            GIF      = 0.05
            WebP     = 0.05
            BMP      = 0.15
        }
    }
}
