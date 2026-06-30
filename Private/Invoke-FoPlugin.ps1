function Invoke-FoPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Step,
        [Parameter(Mandatory)]
        [string]$InputFile,
        [hashtable]$Settings,
        [string]$PluginPath,
        [string]$SearchMode
    )

    $mask = $Settings.DisablePluginMask
    if ($mask) {
        $hay = ($Step.Name + ' ' + $Step.Executable + ' ' + $Step.Handler + ' ' + $Step.Arguments).ToUpperInvariant()
        foreach ($token in ($mask.Split(',') | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { $_ })) {
            if ($hay.Contains($token)) { return @{ ExitCode = 0; Skipped = $true; SizeBefore = 0; SizeAfter = 0 } }
        }
    }

    $tempDir = if ($Settings.TempDirectory) { $Settings.TempDirectory } else { [System.IO.Path]::GetTempPath() }
    $rand = Get-Random -Minimum 0 -Maximum 9999
    $baseName = [System.IO.Path]::GetFileName($InputFile)
    $tmpIn = Join-Path $tempDir "FileOptimizer_Input_${rand}_$baseName"
    $tmpOut = Join-Path $tempDir "FileOptimizer_Output_${rand}_$baseName"

    if (-not $Settings.Debug) {
        foreach ($t in @($tmpIn, $tmpOut)) {
            if (Test-Path -LiteralPath $t) { Remove-Item -LiteralPath $t -Force }
        }
    }

    $stepArgs = $Step.Arguments
    if ($null -eq $stepArgs) { $stepArgs = '' }
    $usesTmpOut = $stepArgs -and ($stepArgs -match '%TMPOUTPUTFILE%')
    $usesTmpInOnly = $stepArgs -and ($stepArgs -match '%TMPINPUTFILE%') -and -not $usesTmpOut -and ($stepArgs -notmatch '%OUTPUTFILE%')

    if ($usesTmpInOnly -or ($Step.Handler -and $Step.Mode -eq 'TempInput')) {
        Copy-Item -LiteralPath $InputFile -Destination $tmpIn -Force
    }

    $sizeBefore = (Get-Item -LiteralPath $InputFile).Length
    $sizeAfter = $sizeBefore
    $exitCode = 0
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    if ($Step.Handler) {
        $handlerMap = @{
            DefluffPipe    = { Invoke-FoDefluffPipe -InputPath $InputFile -OutputPath $tmpOut -DefluffExe (Resolve-FoPluginExecutable -Name 'defluff.exe' -SearchMode $SearchMode -PluginPath $PluginPath).Path }
            GzipRecompress = { Invoke-FoGzipRecompress -InputPath $InputFile -OutputPath $tmpOut -GzipExe (Resolve-FoPluginExecutable -Name 'gzip.exe' -SearchMode $SearchMode -PluginPath $PluginPath).Path }
            JsMinPipe      = { Invoke-FoJsMinPipe -InputPath $InputFile -OutputPath $tmpOut -JsMinExe (Resolve-FoPluginExecutable -Name 'jsmin.exe' -SearchMode $SearchMode -PluginPath $PluginPath).Path }
            SqliteOptimize = { Invoke-FoSqliteOptimize -InputPath $InputFile -OutputPath $tmpOut -SqliteExe (Resolve-FoPluginExecutable -Name 'sqlite3.exe' -SearchMode $SearchMode -PluginPath $PluginPath).Path }
        }
        if ($handlerMap.ContainsKey($Step.Handler)) {
            $exitCode = & $handlerMap[$Step.Handler]
        }
        else {
            $exitCode = 1
        }
    }
    else {
        $argTemplate = $stepArgs
        $argTemplate = $argTemplate.Replace('%INPUTFILE%', "`"$InputFile`"")
        $argTemplate = $argTemplate.Replace('%TMPINPUTFILE%', "`"$tmpIn`"")
        $argTemplate = $argTemplate.Replace('%TMPOUTPUTFILE%', "`"$tmpOut`"")
        $argTemplate = $argTemplate.Replace('%OUTPUTFILE%', '""')

        $resolved = Resolve-FoPluginExecutable -Name $Step.Executable -SearchMode $SearchMode -PluginPath $PluginPath
        if (-not $resolved.Found) {
            return @{ ExitCode = 1; Skipped = $false; Accepted = $false; SizeBefore = $sizeBefore; SizeAfter = $sizeBefore; DurationMs = $sw.ElapsedMilliseconds }
        }
        $exePath = $resolved.Path
        $workDir = if ($resolved.Source -eq 'Portable' -and $PluginPath) { $PluginPath } else { Split-Path -Parent $exePath }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exePath
        $psi.Arguments = $argTemplate
        $psi.WorkingDirectory = $workDir
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $p = [System.Diagnostics.Process]::Start($psi)
        $p.WaitForExit()
        $exitCode = $p.ExitCode
        $p.Dispose()
    }

    $sw.Stop()
    $accepted = $false

    if ($exitCode -eq 0) {
        if ($usesTmpOut -or $Step.Handler) {
            if (Test-Path -LiteralPath $tmpOut) {
                $sizeAfter = (Get-Item -LiteralPath $tmpOut).Length
                if ($sizeAfter -ge 8 -and $sizeAfter -lt $sizeBefore) {
                    Copy-Item -LiteralPath $tmpOut -Destination $InputFile -Force
                    $accepted = $true
                }
            }
        }
        elseif ($usesTmpInOnly) {
            if (Test-Path -LiteralPath $tmpIn) {
                $sizeAfter = (Get-Item -LiteralPath $tmpIn).Length
                if ($sizeAfter -ge 8 -and $sizeAfter -lt $sizeBefore) {
                    Copy-Item -LiteralPath $tmpIn -Destination $InputFile -Force
                    $accepted = $true
                }
            }
        }
        elseif ($stepArgs -match '%TMPOUTPUTFILE%') {
            if (Test-Path -LiteralPath $tmpOut) {
                $sizeAfter = (Get-Item -LiteralPath $tmpOut).Length
                if ($sizeAfter -ge 8 -and $sizeAfter -lt $sizeBefore) {
                    Copy-Item -LiteralPath $tmpOut -Destination $InputFile -Force
                    $accepted = $true
                }
            }
        }
    }

    if (-not $Settings.Debug) {
        foreach ($t in @($tmpIn, $tmpOut)) {
            if (Test-Path -LiteralPath $t) { Remove-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue }
        }
    }

    if ($accepted) {
        $sizeAfter = (Get-Item -LiteralPath $InputFile).Length
    }
    else {
        $sizeAfter = $sizeBefore
    }

    return @{
        ExitCode   = $exitCode
        Skipped    = $false
        Accepted   = $accepted
        SizeBefore = $sizeBefore
        SizeAfter  = $sizeAfter
        DurationMs = $sw.ElapsedMilliseconds
    }
}
