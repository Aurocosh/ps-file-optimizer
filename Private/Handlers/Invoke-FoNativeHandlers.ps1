function Wait-FoHandlerProcessExit {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds
    )

    if ($TimeoutSeconds -gt 0) {
        $timeoutMs = $TimeoutSeconds * 1000
        if (-not $Process.WaitForExit($timeoutMs)) {
            Stop-FoHandlerProcess -Process $Process
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

function Complete-FoAsyncStreamCopy {
    param(
        $AsyncCopy,
        [datetime]$Deadline
    )

    if (-not $AsyncCopy) { return $true }

    while (-not $AsyncCopy.Handle.IsCompleted) {
        if ((Get-Date) -ge $Deadline) {
            return $false
        }
        Start-Sleep -Milliseconds 50
    }

    try {
        $AsyncCopy.PowerShell.EndInvoke($AsyncCopy.Handle)
    }
    catch {
        Write-Debug $_.Exception.Message
    }
    try {
        $AsyncCopy.PowerShell.Dispose()
    }
    catch {
        Write-Debug $_.Exception.Message
    }
    return $true
}

function Stop-FoAsyncStreamCopy {
    param($AsyncCopy)

    if (-not $AsyncCopy) { return }
    try { $AsyncCopy.PowerShell.Stop() } catch { Write-Debug $_.Exception.Message }
    try { $AsyncCopy.PowerShell.Dispose() } catch { Write-Debug $_.Exception.Message }
}

function Stop-FoHandlerProcess {
    param([System.Diagnostics.Process]$Process)

    if (-not $Process -or $Process.HasExited) { return }
    try {
        # Prefer entire process tree so cmd.exe /c stubs cannot leave child tools running.
        $killTree = $Process.GetType().GetMethod('Kill', [type[]]@([bool]))
        if ($killTree) {
            $null = $killTree.Invoke($Process, @($true))
        }
        elseif ($env:OS -match 'Windows') {
            $null = & $env:ComSpec /c "taskkill /T /F /PID $($Process.Id) >nul 2>nul"
        }
        else {
            $Process.Kill()
        }
    }
    catch {
        Write-Debug $_.Exception.Message
    }
    try { $null = $Process.WaitForExit(5000) } catch { Write-Debug $_.Exception.Message }
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
    $inputStream = $null
    $outputStream = $null
    $stderrStream = $null
    $stdinCopy = $null
    $stdoutCopy = $null
    $stderrCopy = $null
    $timedOut = $false
    try {
        # Stdin, stdout, and stderr must run concurrently. Writing the full input before
        # draining stdout deadlocks once the OS pipe buffer fills (~64KB).
        $inputStream = [System.IO.File]::OpenRead($InputPath)
        $outputStream = [System.IO.File]::Create($OutputPath)
        $stderrStream = New-Object System.IO.MemoryStream

        $stdinCopy = Start-FoAsyncStreamCopy -From $inputStream -To $p.StandardInput.BaseStream
        $stdoutCopy = Start-FoAsyncStreamCopy -From $p.StandardOutput.BaseStream -To $outputStream
        $stderrCopy = Start-FoAsyncStreamCopy -From $p.StandardError.BaseStream -To $stderrStream

        $deadline = if ($TimeoutSeconds -gt 0) {
            (Get-Date).AddSeconds($TimeoutSeconds)
        }
        else {
            [datetime]::MaxValue
        }

        if (-not (Complete-FoAsyncStreamCopy -AsyncCopy $stdinCopy -Deadline $deadline)) {
            $timedOut = $true
            return -1
        }
        $stdinCopy = $null
        try { $p.StandardInput.Close() } catch { Write-Debug $_.Exception.Message }

        while (-not $p.HasExited) {
            if ((Get-Date) -ge $deadline) {
                $timedOut = $true
                return -1
            }
            Start-Sleep -Milliseconds 50
        }

        $drainDeadline = if ($TimeoutSeconds -gt 0) { (Get-Date).AddSeconds(5) } else { [datetime]::MaxValue }
        if (-not (Complete-FoAsyncStreamCopy -AsyncCopy $stdoutCopy -Deadline $drainDeadline)) {
            $timedOut = $true
            return -1
        }
        $stdoutCopy = $null
        if (-not (Complete-FoAsyncStreamCopy -AsyncCopy $stderrCopy -Deadline $drainDeadline)) {
            $timedOut = $true
            return -1
        }
        $stderrCopy = $null

        if ($p.ExitCode -ne 0) { return $p.ExitCode }
        if (-not (Test-Path -LiteralPath $OutputPath)) { return 1 }
        return 0
    }
    finally {
        Stop-FoHandlerProcess -Process $p
        Stop-FoAsyncStreamCopy -AsyncCopy $stdinCopy
        Stop-FoAsyncStreamCopy -AsyncCopy $stdoutCopy
        Stop-FoAsyncStreamCopy -AsyncCopy $stderrCopy
        foreach ($stream in @($inputStream, $outputStream, $stderrStream)) {
            if ($stream) {
                try { $stream.Dispose() } catch { Write-Debug $_.Exception.Message }
            }
        }
        if ($p) { $p.Dispose() }
        if ($timedOut -and (Test-Path -LiteralPath $OutputPath)) {
            Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue
        }
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
        $stderrStream = New-Object System.IO.MemoryStream
        $stdinCopy = $null
        $stdoutCopy = $null
        $stderrCopy = $null
        try {
            # Concurrent stdin/stdout/stderr — sequential copy deadlocks on large payloads.
            $stdinCopy = Start-FoAsyncStreamCopy -From $inStream -To $cp.StandardInput.BaseStream
            $stdoutCopy = Start-FoAsyncStreamCopy -From $cp.StandardOutput.BaseStream -To $outStream
            $stderrCopy = Start-FoAsyncStreamCopy -From $cp.StandardError.BaseStream -To $stderrStream

            $deadline = if ($TimeoutSeconds -gt 0) {
                (Get-Date).AddSeconds($TimeoutSeconds)
            }
            else {
                [datetime]::MaxValue
            }

            if (-not (Complete-FoAsyncStreamCopy -AsyncCopy $stdinCopy -Deadline $deadline)) {
                return -1
            }
            $stdinCopy = $null
            try { $cp.StandardInput.Close() } catch { Write-Debug $_.Exception.Message }

            while (-not $cp.HasExited) {
                if ((Get-Date) -ge $deadline) {
                    return -1
                }
                Start-Sleep -Milliseconds 50
            }

            $drainDeadline = if ($TimeoutSeconds -gt 0) { (Get-Date).AddSeconds(5) } else { [datetime]::MaxValue }
            if (-not (Complete-FoAsyncStreamCopy -AsyncCopy $stdoutCopy -Deadline $drainDeadline)) {
                return -1
            }
            $stdoutCopy = $null
            if (-not (Complete-FoAsyncStreamCopy -AsyncCopy $stderrCopy -Deadline $drainDeadline)) {
                return -1
            }
            $stderrCopy = $null
        }
        finally {
            Stop-FoHandlerProcess -Process $cp
            Stop-FoAsyncStreamCopy -AsyncCopy $stdinCopy
            Stop-FoAsyncStreamCopy -AsyncCopy $stdoutCopy
            Stop-FoAsyncStreamCopy -AsyncCopy $stderrCopy
            $inStream.Dispose()
            $outStream.Dispose()
            $stderrStream.Dispose()
        }

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
