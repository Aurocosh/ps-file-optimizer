BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'FoTestSupport\FoTestSupport.psd1') -Force
}

Describe 'Invoke-FoGzipRecompress' -Tag Unit -Skip:(-not (
        (Resolve-FoPluginExecutable -Name 'gzip.exe' -SearchMode PathOnly).Found -or
        (Test-FoPluginsAvailable -RequiredExecutables @('gzip.exe'))
    )) {
    BeforeAll {
        $script:GzipExe = if ((Test-FoPluginsAvailable -RequiredExecutables @('gzip.exe'))) {
            (Resolve-FoPluginExecutable -Name 'gzip.exe' -SearchMode PortableOnly -PluginPath (Get-FoTestPluginPath)).Path
        }
        else {
            (Resolve-FoPluginExecutable -Name 'gzip.exe' -SearchMode PathOnly).Path
        }
    }

    It 'Preserves binary payload through recompress' {
        $workDir = Join-Path $TestDrive 'gzip-binary'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $inputPath = Join-Path $workDir 'payload.gz'
        $outputPath = Join-Path $workDir 'payload.out.gz'
        $payload = [byte[]](0..255)

        $ms = New-Object System.IO.MemoryStream
        $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Compress)
        $gz.Write($payload, 0, $payload.Length)
        $gz.Dispose()
        [System.IO.File]::WriteAllBytes($inputPath, $ms.ToArray())
        $ms.Dispose()

        $exitCode = Invoke-FoGzipRecompress -InputPath $inputPath -OutputPath $outputPath -GzipExe $script:GzipExe
        $exitCode | Should -Be 0
        (Test-Path -LiteralPath $outputPath) | Should -Be $true

        $fs = [System.IO.File]::OpenRead($outputPath)
        try {
            $gzIn = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress)
            $out = New-Object System.IO.MemoryStream
            $gzIn.CopyTo($out)
            $gzIn.Dispose()
            $roundTrip = $out.ToArray()
        }
        finally {
            $fs.Dispose()
        }

        $roundTrip.Length | Should -Be $payload.Length
        for ($i = 0; $i -lt $payload.Length; $i++) {
            $roundTrip[$i] | Should -Be $payload[$i]
        }
    }

    It 'Produces valid gzip output via gzip -t' {
        $workDir = Join-Path $TestDrive 'gzip-valid'
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        $inputPath = Join-Path $workDir 'sample.gz'
        $outputPath = Join-Path $workDir 'sample.out.gz'
        $payload = [byte[]](0x00, 0xFF, 0x80, 0x7F, 0x01, 0xFE) * 40

        $ms = New-Object System.IO.MemoryStream
        $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Compress)
        $gz.Write($payload, 0, $payload.Length)
        $gz.Dispose()
        [System.IO.File]::WriteAllBytes($inputPath, $ms.ToArray())
        $ms.Dispose()

        $exitCode = Invoke-FoGzipRecompress -InputPath $inputPath -OutputPath $outputPath -GzipExe $script:GzipExe
        $exitCode | Should -Be 0

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:GzipExe
        $psi.Arguments = "-t `"$outputPath`""
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.WaitForExit()
        $p.ExitCode | Should -Be 0
        $p.Dispose()
    }
}
