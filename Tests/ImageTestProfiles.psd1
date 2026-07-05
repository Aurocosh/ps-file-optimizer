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
        # SSIM dissimilarity ceilings (0 = identical). Calibrated 2026-07 on Tier A + 256x256 PNG with bundled plugins.
        # Observed: JPEG 0.0049, WebP 0.0285, GIF/PNG micro-fixtures 0. Margin +0.005-0.01.
        SSIMDissimilarityMaximum = @{
            Default = 0.02
            JPEG    = 0.015
            PNG     = 0.01
            GIF     = 0.05
            WebP    = 0.035
        }
    }
}
