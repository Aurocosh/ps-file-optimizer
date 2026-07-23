function Wait-FoHandlerProcessExit {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds
    )

    if ($TimeoutSeconds -gt 0) {
        $timeoutMs = $TimeoutSeconds * 1000
        if (-not $Process.WaitForExit($timeoutMs)) {
            try { $Process.Kill() } catch { Write-Debug $_.Exception.Message }
            try { $Process.WaitForExit(5000) } catch { Write-Debug $_.Exception.Message }
            return $false
        }
        return $true
    }

    $Process.WaitForExit()
    return $true
}

function Start-FoAsyncStreamCopy {
    param(
        [System.IO.Stream]$From,
        [System.IO.Stream]$To
    )

    $ps = [powershell]::Create()
    [void]$ps.AddScript({
        param([System.IO.Stream]$FromStream, [System.IO.Stream]$ToStream)
        $FromStream.CopyTo($ToStream)
    }).AddArgument($From).AddArgument($To)
    $handle = $ps.BeginInvoke()
    return [PSCustomObject]@{
        PowerShell = $ps
        Handle     = $handle
    }
}

function Wait-FoAsyncStreamCopy {
    param(
        $AsyncCopy,
        [int]$TimeoutSeconds
    )

    if (-not $AsyncCopy) { return $true }

    if ($TimeoutSeconds -le 0) {
        $AsyncCopy.PowerShell.EndInvoke($AsyncCopy.Handle)
        $AsyncCopy.PowerShell.Dispose()
        return $true
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $AsyncCopy.Handle.IsCompleted) {
        if ($sw.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            try { $AsyncCopy.PowerShell.Stop() } catch { Write-Debug $_.Exception.Message }
            try { $AsyncCopy.PowerShell.Dispose() } catch { Write-Debug $_.Exception.Message }
            return $false
        }
        Start-Sleep -Milliseconds 50
    }

    $AsyncCopy.PowerShell.EndInvoke($AsyncCopy.Handle)
    $AsyncCopy.PowerShell.Dispose()
    return $true
}

function Wait-FoGzipHandlerPipeline {
    param(
        [System.Diagnostics.Process[]]$Processes,
        [int]$TimeoutSeconds
    )

    if ($TimeoutSeconds -le 0) {
        foreach ($proc in $Processes) {
            if ($proc -and -not $proc.HasExited) { $proc.WaitForExit() }
        }
        return $true
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ($true) {
        $pending = $false
        foreach ($proc in $Processes) {
            if ($proc -and -not $proc.HasExited) { $pending = $true; break }
        }
        if (-not $pending) { return $true }
        if ((Get-Date) -ge $deadline) {
            foreach ($proc in $Processes) {
                if ($proc -and -not $proc.HasExited) {
                    try { $proc.Kill() } catch { Write-Debug $_.Exception.Message }
                }
            }
            return $false
        }
        Start-Sleep -Milliseconds 50
    }
}

function Invoke-FoDefluffPipe {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [string]$DefluffExe,
        [int]$TimeoutSeconds = 0
    )

    if (-not $DefluffExe -or -not (Test-Path -LiteralPath $DefluffExe)) { return 1 }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($DefluffExe -match '\.(cmd|bat)$') {
        $psi.FileName = $env:ComSpec
        $psi.Arguments = '/c ' + (Format-FoProcessArgument $DefluffExe)
        $workDir = $env:SystemRoot
    }
    else {
        $psi.FileName = $DefluffExe
        $workDir = Split-Path -Parent $DefluffExe
    }
    $psi.WorkingDirectory = $workDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $p = [System.Diagnostics.Process]::Start($psi)
    try {
        if ($TimeoutSeconds -gt 0) {
            $inputStream = [System.IO.File]::OpenRead($InputPath)
            try {
                $stdinCopy = Start-FoAsyncStreamCopy -From $inputStream -To $p.StandardInput.BaseStream
                if (-not (Wait-FoAsyncStreamCopy -AsyncCopy $stdinCopy -TimeoutSeconds $TimeoutSeconds)) {
                    try { $p.StandardInput.Close() } catch { Write-Debug $_.Exception.Message }
                    if (-not $p.HasExited) { try { $p.Kill() } catch { Write-Debug $_.Exception.Message } }
                    if (Test-Path -LiteralPath $OutputPath) {
                        Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue
                    }
                    return -1
                }
            }
            finally {
                $inputStream.Dispose()
            }
            $p.StandardInput.Close()
        }
        else {
            $inputStream = [System.IO.File]::OpenRead($InputPath)
            try {
                $inputStream.CopyTo($p.StandardInput.BaseStream)
            }
            finally {
                $inputStream.Dispose()
            }
            $p.StandardInput.Close()
        }

        $outputStream = [System.IO.File]::Create($OutputPath)
        try {
            if ($TimeoutSeconds -gt 0) {
                $stdoutCopy = Start-FoAsyncStreamCopy -From $p.StandardOutput.BaseStream -To $outputStream
                if (-not (Wait-FoGzipHandlerPipeline -Processes @($p) -TimeoutSeconds $TimeoutSeconds)) {
                    if (Test-Path -LiteralPath $OutputPath) {
                        Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue
                    }
                    return -1
                }
                if (-not (Wait-FoAsyncStreamCopy -AsyncCopy $stdoutCopy -TimeoutSeconds 5)) {
                    if (Test-Path -LiteralPath $OutputPath) {
                        Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue
                    }
                    return -1
                }
            }
            else {
                $p.StandardOutput.BaseStream.CopyTo($outputStream)
                if (-not (Wait-FoHandlerProcessExit -Process $p -TimeoutSeconds 0)) {
                    return -1
                }
            }
        }
        finally {
            $outputStream.Dispose()
        }
        $p.StandardOutput.Close()
        $null = $p.StandardError.ReadToEnd()

        if ($p.ExitCode -ne 0) { return $p.ExitCode }
        if (-not (Test-Path -LiteralPath $OutputPath)) { return 1 }
        return 0
    }
    finally {
        if ($p -and -not $p.HasExited) { $p.Kill() }
        if ($p) { $p.Dispose() }
    }
}

function Invoke-FoGzipRecompress {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [string]$GzipExe,
        [int]$TimeoutSeconds = 0
    )

    $tempRaw = Join-Path ([System.IO.Path]::GetTempPath()) ('fo_gzip_{0}.bin' -f ([guid]::NewGuid().ToString('N')))
    $dp = $null
    $cp = $null

    try {
        $decomp = New-Object System.Diagnostics.ProcessStartInfo
        $decomp.FileName = $GzipExe
        $decomp.Arguments = '-cd ' + (Format-FoProcessArgument $InputPath)
        $decomp.UseShellExecute = $false
        $decomp.RedirectStandardOutput = $true
        $decomp.RedirectStandardError = $true
        $decomp.CreateNoWindow = $true
        $dp = [System.Diagnostics.Process]::Start($decomp)

        $rawStream = [System.IO.File]::Create($tempRaw)
        try {
            if ($TimeoutSeconds -gt 0) {
                $decompCopy = Start-FoAsyncStreamCopy -From $dp.StandardOutput.BaseStream -To $rawStream
                if (-not (Wait-FoGzipHandlerPipeline -Processes @($dp) -TimeoutSeconds $TimeoutSeconds)) {
                    return -1
                }
                if (-not (Wait-FoAsyncStreamCopy -AsyncCopy $decompCopy -TimeoutSeconds 5)) {
                    return -1
                }
            }
            else {
                $dp.StandardOutput.BaseStream.CopyTo($rawStream)
                $dp.WaitForExit()
            }
        }
        finally {
            $rawStream.Dispose()
            $dp.StandardOutput.Close()
        }

        $null = $dp.StandardError.ReadToEnd()
        if ($dp.ExitCode -ne 0) { return $dp.ExitCode }

        $comp = New-Object System.Diagnostics.ProcessStartInfo
        $comp.FileName = $GzipExe
        $comp.Arguments = '-12 -f'
        $comp.UseShellExecute = $false
        $comp.RedirectStandardInput = $true
        $comp.RedirectStandardOutput = $true
        $comp.RedirectStandardError = $true
        $comp.CreateNoWindow = $true
        $cp = [System.Diagnostics.Process]::Start($comp)

        $inStream = [System.IO.File]::OpenRead($tempRaw)
        $outStream = [System.IO.File]::Create($OutputPath)
        try {
            if ($TimeoutSeconds -gt 0) {
                $stdinCopy = Start-FoAsyncStreamCopy -From $inStream -To $cp.StandardInput.BaseStream
                if (-not (Wait-FoAsyncStreamCopy -AsyncCopy $stdinCopy -TimeoutSeconds $TimeoutSeconds)) {
                    return -1
                }
                $cp.StandardInput.Close()
                $stdoutCopy = Start-FoAsyncStreamCopy -From $cp.StandardOutput.BaseStream -To $outStream
                if (-not (Wait-FoGzipHandlerPipeline -Processes @($cp) -TimeoutSeconds $TimeoutSeconds)) {
                    return -1
                }
                if (-not (Wait-FoAsyncStreamCopy -AsyncCopy $stdoutCopy -TimeoutSeconds 5)) {
                    return -1
                }
            }
            else {
                $inStream.CopyTo($cp.StandardInput.BaseStream)
                $cp.StandardInput.Close()
                $cp.StandardOutput.BaseStream.CopyTo($outStream)
                $cp.WaitForExit()
            }
        }
        finally {
            $inStream.Dispose()
            $outStream.Dispose()
            $cp.StandardOutput.Close()
        }

        $null = $cp.StandardError.ReadToEnd()
        if ($cp.ExitCode -ne 0) { return $cp.ExitCode }
        return 0
    }
    finally {
        foreach ($proc in @($dp, $cp)) {
            if ($proc -and -not $proc.HasExited) {
                try { $proc.Kill() } catch { Write-Debug $_.Exception.Message }
            }
            if ($proc) { $proc.Dispose() }
        }
        if (Test-Path -LiteralPath $tempRaw) {
            Remove-Item -LiteralPath $tempRaw -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-FoJsMinPipe {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [string]$JsMinExe,
        [int]$TimeoutSeconds = 0
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($JsMinExe -match '\.(cmd|bat)$') {
        $psi.FileName = $env:ComSpec
        $psi.Arguments = '/c ' + (Format-FoProcessArgument $JsMinExe)
    }
    else {
        $psi.FileName = $JsMinExe
    }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    try {
        $text = [System.IO.File]::ReadAllText($InputPath)
        $p.StandardInput.Write($text)
        $p.StandardInput.Close()
        if (-not (Wait-FoHandlerProcessExit -Process $p -TimeoutSeconds $TimeoutSeconds)) {
            if (Test-Path -LiteralPath $OutputPath) {
                Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue
            }
            return -1
        }
        $out = $p.StandardOutput.ReadToEnd()
        if ($p.ExitCode -ne 0) { return $p.ExitCode }
        [System.IO.File]::WriteAllText($OutputPath, $out)
        return 0
    }
    finally {
        if (-not $p.HasExited) { $p.Kill() }
        $p.Dispose()
    }
}

function Invoke-FoSqliteProcess {
    param(
        [string]$SqliteExe,
        [string]$Arguments,
        [int]$TimeoutSeconds = 0,
        [switch]$CaptureStdout
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $SqliteExe
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    if ($CaptureStdout) {
        $psi.RedirectStandardOutput = $true
    }

    $p = [System.Diagnostics.Process]::Start($psi)
    try {
        $stdout = $null
        if ($CaptureStdout) {
            $stdout = $p.StandardOutput.ReadToEnd()
        }
        $null = $p.StandardError.ReadToEnd()
        if (-not (Wait-FoHandlerProcessExit -Process $p -TimeoutSeconds $TimeoutSeconds)) {
            return @{ ExitCode = -1; Output = $null }
        }
        return @{ ExitCode = $p.ExitCode; Output = $stdout }
    }
    finally {
        if ($p -and -not $p.HasExited) { $p.Kill() }
        if ($p) { $p.Dispose() }
    }
}

function Invoke-FoSqliteOptimize {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [string]$SqliteExe,
        [int]$TimeoutSeconds = 0
    )

    $tempDir = [System.IO.Path]::GetTempPath()
    $sqlFile = Join-Path $tempDir ("FileOptimizer_sqlite_{0}.sql" -f (Get-Random -Maximum 999999))
    if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }

    try {
        Set-Content -LiteralPath $sqlFile -Value 'PRAGMA optimize(0xfffe);' -Encoding UTF8
        $dumpArgs = '{0} .dump' -f (Format-FoProcessArgument $InputPath)
        $dump = Invoke-FoSqliteProcess -SqliteExe $SqliteExe -Arguments $dumpArgs -TimeoutSeconds $TimeoutSeconds -CaptureStdout
        if ($dump.ExitCode -eq -1) { return -1 }
        if ($dump.ExitCode -ne 0) { return $dump.ExitCode }
        Add-Content -LiteralPath $sqlFile -Value $dump.Output -Encoding UTF8
        $readCmd = '.read {0}' -f (Format-FoProcessArgument $sqlFile)
        $readArgs = '{0} {1}' -f (Format-FoProcessArgument $OutputPath), (Format-FoProcessArgument $readCmd)
        $read = Invoke-FoSqliteProcess -SqliteExe $SqliteExe -Arguments $readArgs -TimeoutSeconds $TimeoutSeconds
        if ($read.ExitCode -eq -1) {
            if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
            return -1
        }
        if ($read.ExitCode -ne 0) {
            if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
            return $read.ExitCode
        }
        return 0
    }
    finally {
        if (Test-Path -LiteralPath $sqlFile) { Remove-Item -LiteralPath $sqlFile -Force }
    }
}
