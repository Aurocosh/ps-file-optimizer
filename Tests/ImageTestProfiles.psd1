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
        # SSIM dissimilarity ceilings (0 = identical). Calibrated 2026-07 on Tier A with bundled plugins.
        # PNG: 256x256 generated fixture ~0.01. PNGMicro: pngsuite 32x32 at L9 ~0.04-0.17 (palette outlier basn3p04 uses manifest override).
        # JPEG testorig12 ~0.0157; WebP lossy ~0.0285.
        SSIMDissimilarityMaximum = @{
            Default  = 0.02
            JPEG     = 0.016
            PNG      = 0.01
            PNGMicro = 0.18
            GIF      = 0.05
            WebP     = 0.035
        }
    }
}
