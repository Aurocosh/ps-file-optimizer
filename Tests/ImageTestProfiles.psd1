@{
    LosslessDefault = @{
        PNGAllowLossy  = $false
        JPEGAllowLossy = $false
        GIFAllowLossy  = $false
        WEBPAllowLossy = $false
        Level          = 5
        OutputMode     = 'Replace'
        HistoryEnabled = $false
    }
    LossyHighQuality = @{
        PNGAllowLossy  = $true
        JPEGAllowLossy = $true
        GIFAllowLossy  = $true
        WEBPAllowLossy = $true
        Level          = 9
        OutputMode     = 'Replace'
        HistoryEnabled = $false
    }
}
