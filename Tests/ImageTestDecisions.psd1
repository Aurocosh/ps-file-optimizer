@{
    # Resolved in Phase 0 — see file-optimizer-dev/ps-optimizer/plans/01-image-testing-suite.md
    JpegPrimaryMode           = 'PixelAE'
    JpegSSIMFallbackMinimum   = 0.999
    IcoCompareScope           = 'LargestEmbedded'
    AvifDefaultSSIMMinimum      = 0.995
    PythonCrossCheckPhase     = 7
    FixtureBudgetBytes        = 512000

    # Pester tags — see Tests/README.md
    Tags = @{
        Unit             = 'No plugin binaries required'
        ImageIntegration = 'Requires real plugin folder (magick.exe and optimization tools)'
        Lossy            = 'Uses *AllowLossy settings profiles'
        Slow             = 'Level 9 or large fixtures; exclude from fast CI'
    }
}
