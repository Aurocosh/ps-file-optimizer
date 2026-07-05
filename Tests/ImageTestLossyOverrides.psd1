@{
    # Per-path SSIM dissimilarity ceilings for LossyHighQuality corpus sweeps.
    # Keys use forward slashes relative to corpus root (Tier A/B/C/D).
    # Tier A manifest LossySSIMMaximum is merged automatically; list extras here.
    Paths = @{
        'gb82-sc/graph.png'                                = 1.40
        'jpeg-conformance/valid/cymk.jpg'                  = 0.018
        'jpeg-conformance/valid/grayscale_long.jpg'        = 2.40
        'jpeg-conformance/valid/partial_progressive.jpg'   = 0.10
        'jpeg-conformance/valid/restarts.jpg'              = 0.04
        'pngsuite/basi3p01.png'                            = 2.52
        'pngsuite/basi3p04.png'                           = 1.05
        'pngsuite/basn3p01.png'                            = 2.52
        'pngsuite/ch1n3p04.png'                            = 1.05
        'pngsuite/cdsn2c08.png'                            = 4.80
        'pngsuite/cs3n3p08.png'                            = 2.02
    }
}
