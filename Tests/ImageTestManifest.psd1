@{
    Version         = 'FO-ImageTest-v1'
    UpstreamRepo    = 'https://github.com/imazen/codec-corpus'
    UpstreamCommit  = 'bb1da434fd3ab9ef58577f505d2f9194123e5d6e'
    SparsePaths     = @(
        'pngsuite'
        'gif-conformance'
        'apng-conformance'
        'jpeg-conformance'
        'mozjpeg'
        'webp-conformance'
        'bmp-conformance'
        'image-rs'
        'gb82'
        'gb82-sc'
    )

    Tiers = @{
        A = @{
            Description = 'Bootstrap — committed under Tests/Fixtures/Images/'
            Committed   = $true
            TotalBytes  = 44060
            FileCount   = 31
            Files       = @(
                @{ Id = 'png-basn0g01'; Source = 'pngsuite/basn0g01.png'; Format = 'PNG'; Bytes = 164; Tags = @('PNG', 'grayscale') }
                @{ Id = 'png-basn0g04'; Source = 'pngsuite/basn0g04.png'; Format = 'PNG'; Bytes = 145; Tags = @('PNG', 'grayscale') }
                @{ Id = 'png-basn0g08'; Source = 'pngsuite/basn0g08.png'; Format = 'PNG'; Bytes = 138; Tags = @('PNG', 'grayscale') }
                @{ Id = 'png-basn2c08'; Source = 'pngsuite/basn2c08.png'; Format = 'PNG'; Bytes = 145; Tags = @('PNG', 'rgb') }
                @{ Id = 'png-basn3p04'; Source = 'pngsuite/basn3p04.png'; Format = 'PNG'; Bytes = 216; Tags = @('PNG', 'palette') }
                @{ Id = 'png-basn4a08'; Source = 'pngsuite/basn4a08.png'; Format = 'PNG'; Bytes = 126; Tags = @('PNG', 'alpha') }
                @{ Id = 'png-basn6a08'; Source = 'pngsuite/basn6a08.png'; Format = 'PNG'; Bytes = 184; Tags = @('PNG', 'rgba') }
                @{ Id = 'png-basn0g16'; Source = 'pngsuite/basn0g16.png'; Format = 'PNG'; Bytes = 167; Tags = @('PNG', 'deep') }
                @{ Id = 'png-basi6a08'; Source = 'pngsuite/basi6a08.png'; Format = 'PNG'; Bytes = 361; Tags = @('PNG', 'interlaced') }
                @{ Id = 'png-f00n0g08'; Source = 'pngsuite/f00n0g08.png'; Format = 'PNG'; Bytes = 319; Tags = @('PNG', 'filter-none') }
                @{ Id = 'png-f01n0g08'; Source = 'pngsuite/f01n0g08.png'; Format = 'PNG'; Bytes = 321; Tags = @('PNG', 'filter-sub') }
                @{ Id = 'png-f02n0g08'; Source = 'pngsuite/f02n0g08.png'; Format = 'PNG'; Bytes = 355; Tags = @('PNG', 'filter-up') }
                @{ Id = 'png-f03n0g08'; Source = 'pngsuite/f03n0g08.png'; Format = 'PNG'; Bytes = 389; Tags = @('PNG', 'filter-average') }
                @{ Id = 'jpg-testorig'; Source = 'mozjpeg/testorig.jpg'; Format = 'JPEG'; Bytes = 5770; Tags = @('JPEG', 'baseline') }
                @{ Id = 'jpg-testimgint'; Source = 'mozjpeg/testimgint.jpg'; Format = 'JPEG'; Bytes = 5756; Tags = @('JPEG', 'integer-dct') }
                @{ Id = 'jpg-testimgari'; Source = 'mozjpeg/testimgari.jpg'; Format = 'JPEG'; Bytes = 5126; Tags = @('JPEG', 'arithmetic') }
                @{ Id = 'jpg-testorig12'; Source = 'mozjpeg/testorig12.jpg'; Format = 'JPEG'; Bytes = 12394; Tags = @('JPEG', '12bit') }
                @{ Id = 'jpg-gray-square'; Source = 'jpeg-conformance/valid/grayscale_square.jpg'; Format = 'JPEG'; Bytes = 331; Tags = @('JPEG', 'grayscale') }
                @{ Id = 'jpg-prog-rst'; Source = 'jpeg-conformance/valid/progressive_rst_420.jpg'; Format = 'JPEG'; Bytes = 479; Tags = @('JPEG', 'progressive') }
                @{ Id = 'jpg-extraneous'; Source = 'jpeg-conformance/valid/extraneous-data.jpg'; Format = 'JPEG'; Bytes = 449; Tags = @('JPEG', 'extraneous-data') }
                @{ Id = 'gif-anim3'; Source = 'gif-conformance/valid/anim_3frame_rgb.gif'; Format = 'GIF'; Bytes = 129; Tags = @('GIF', 'animated') }
                @{ Id = 'gif-transparent'; Source = 'gif-conformance/valid/transparent_frame.gif'; Format = 'GIF'; Bytes = 106; Tags = @('GIF', 'transparent') }
                @{ Id = 'gif-palette256'; Source = 'gif-conformance/valid/static_256colors.gif'; Format = 'GIF'; Bytes = 1095; Tags = @('GIF', 'palette') }
                @{ Id = 'apng-3frame'; Source = 'apng-conformance/valid/3frame_rgb.png'; Format = 'APNG'; Bytes = 273; Tags = @('APNG', 'animated') }
                @{ Id = 'apng-dispose'; Source = 'apng-conformance/valid/dispose_background.png'; Format = 'APNG'; Bytes = 273; Tags = @('APNG', 'disposal') }
                @{ Id = 'webp-lossless'; Source = 'webp-conformance/valid/2-color.webp'; Format = 'WebP'; Bytes = 314; Tags = @('WebP', 'lossless') }
                @{ Id = 'webp-lossy'; Source = 'webp-conformance/valid/simple-rgb.webp'; Format = 'WebP'; Bytes = 2184; Tags = @('WebP', 'lossy') }
                @{ Id = 'bmp-rle'; Source = 'bmp-conformance/valid/g04rle.bmp'; Format = 'BMP'; Bytes = 922; Tags = @('BMP', 'rle') }
                @{ Id = 'bmp-1bit'; Source = 'image-rs/test-images/bmp/images/Info_1_Bit.bmp'; Format = 'BMP'; Bytes = 88; Tags = @('BMP', '1bit') }
                @{ Id = 'ico-smile'; Source = 'image-rs/test-images/ico/images/smile.ico'; Format = 'ICO'; Bytes = 1078; Tags = @('ICO') }
                @{ Id = 'jpg-exif-xmp'; Source = 'image-rs/test-images/jpg/exif-xmp-metadata.jpg'; Format = 'JPEG'; Bytes = 4263; Tags = @('JPEG', 'metadata') }
            )
        }

        B = @{
            Description = 'Standard integration — download via Get-ImageTestCorpus.ps1'
            Committed   = $false
            Rules       = @(
                'pngsuite/*.png excluding x*.png'
                'gif-conformance/valid/*'
                'apng-conformance/valid/*'
                'jpeg-conformance/valid/* excluding ycck.jpg, cmyk_logo.jpg, Reconyx_*; max 200KB'
                'mozjpeg/*.{jpg,bmp}'
                'webp-conformance/valid/{2-color,simple-rgb,simple-gray,anim,lossy_alpha}.webp'
                'bmp-conformance/valid/* max 20KB'
                'image-rs/test-images/jpg/**/*.jpg'
                'image-rs/test-images/tiff/testsuite/l1.tiff'
                'gb82-sc/windows95.png, gb82-sc/graph.png'
            )
        }

        C = @{
            Description = 'Photographic nightly — gb82/ all 25 PNGs (~9.6 MB)'
            Committed   = $false
            SourceGlob  = 'gb82/*-lossless.png'
            Tags        = @('Slow')
        }

        D = @{
            Description = 'Lossy calibration optional — GB82-SC, GB82 subset, CLIC/CID22 download only'
            Committed   = $false
            Note        = 'Do not commit CID22 binaries (CC BY-SA 4.0)'
        }
    }

    Excluded = @(
        '*/invalid/*'
        '*/non-conformant/*'
        '*/crash-repro/*'
        'zune/**'
        'heic-conformance/**'
        'pngsuite/x*.png'
        'jpeg-conformance/valid/ycck.jpg'
        'jpeg-conformance/valid/cmyk_logo.jpg'
        'jpeg-conformance/valid/Reconyx_HC500_Hyperfire.jpg'
        'image-rs/**/Bad_*'
        'image-rs/**/*.bad_*'
    )
}
