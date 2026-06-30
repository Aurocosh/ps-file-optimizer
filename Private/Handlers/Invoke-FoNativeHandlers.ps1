function Invoke-FoDefluffPipe {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [string]$DefluffExe
    )

    if (-not $DefluffExe -or -not (Test-Path -LiteralPath $DefluffExe)) { return 1 }

    $workDir = Split-Path -Parent $DefluffExe
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'cmd.exe'
    $psi.Arguments = "/c `"`"$DefluffExe`" < `"$InputPath`" > `"$OutputPath`"`""
    $psi.WorkingDirectory = $workDir
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    $exitCode = $p.ExitCode
    $p.Dispose()

    if ($exitCode -ne 0) { return $exitCode }
    if (-not (Test-Path -LiteralPath $OutputPath)) { return 1 }
    return 0
}

function Invoke-FoGzipRecompress {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [string]$GzipExe
    )

    $decomp = New-Object System.Diagnostics.ProcessStartInfo
    $decomp.FileName = $GzipExe
    $decomp.Arguments = "-cd `"$InputPath`""
    $decomp.UseShellExecute = $false
    $decomp.RedirectStandardOutput = $true
    $decomp.RedirectStandardError = $true
    $decomp.CreateNoWindow = $true
    $dp = [System.Diagnostics.Process]::Start($decomp)

    $comp = New-Object System.Diagnostics.ProcessStartInfo
    $comp.FileName = $GzipExe
    $comp.Arguments = "-12 -f"
    $comp.UseShellExecute = $false
    $comp.RedirectStandardInput = $true
    $comp.RedirectStandardOutput = $true
    $comp.RedirectStandardError = $true
    $comp.CreateNoWindow = $true
    $cp = [System.Diagnostics.Process]::Start($comp)

    try {
        $dp.StandardOutput.BaseStream.CopyTo($cp.StandardInput.BaseStream)
        $dp.StandardOutput.Close()
        $cp.StandardInput.Close()
        $dp.WaitForExit()
        $stdout = $cp.StandardOutput.ReadToEnd()
        $cp.WaitForExit()
        if ($dp.ExitCode -ne 0) { return $dp.ExitCode }
        if ($cp.ExitCode -ne 0) { return $cp.ExitCode }
        [System.IO.File]::WriteAllBytes($OutputPath, [System.Text.Encoding]::Latin1.GetBytes($stdout))
        return 0
    }
    finally {
        foreach ($proc in @($dp, $cp)) {
            if ($proc -and -not $proc.HasExited) { $proc.Kill() }
            if ($proc) { $proc.Dispose() }
        }
    }
}

function Invoke-FoJsMinPipe {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [string]$JsMinExe
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $JsMinExe
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    try {
        $text = [System.IO.File]::ReadAllText($InputPath)
        $p.StandardInput.Write($text)
        $p.StandardInput.Close()
        $out = $p.StandardOutput.ReadToEnd()
        $p.WaitForExit()
        if ($p.ExitCode -ne 0) { return $p.ExitCode }
        [System.IO.File]::WriteAllText($OutputPath, $out)
        return 0
    }
    finally {
        if (-not $p.HasExited) { $p.Kill() }
        $p.Dispose()
    }
}

function Invoke-FoSqliteOptimize {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [string]$SqliteExe
    )

    $sqlFile = "$InputPath.sql"
    if (Test-Path -LiteralPath $sqlFile) { Remove-Item -LiteralPath $sqlFile -Force }
    if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }

    try {
        Set-Content -LiteralPath $sqlFile -Value 'PRAGMA optimize(0xfffe);' -Encoding UTF8
        $dump = & $SqliteExe $InputPath '.dump' 2>&1
        if ($LASTEXITCODE -ne 0) { return $LASTEXITCODE }
        Add-Content -LiteralPath $sqlFile -Value ($dump -join "`n") -Encoding UTF8
        & $SqliteExe $OutputPath ".read $sqlFile" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
            return $LASTEXITCODE
        }
        return 0
    }
    finally {
        if (Test-Path -LiteralPath $sqlFile) { Remove-Item -LiteralPath $sqlFile -Force }
    }
}
