function Test-FoDisablePluginMaskMatch {
    param(
        [string]$Mask,
        [string]$Haystack
    )

    if ([string]::IsNullOrWhiteSpace($Mask)) { return $false }
    if ([string]::IsNullOrWhiteSpace($Haystack)) { return $false }

    $hay = $Haystack.ToUpperInvariant()
    foreach ($token in ($Mask.Split(',') | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { $_ })) {
        if ($hay.Contains($token)) { return $true }
    }
    return $false
}

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

    $tempDir = if ($Settings.TempDirectory) { $Settings.TempDirectory } else { [System.IO.Path]::GetTempPath() }
    if ($Settings.TempDirectory -and -not (Test-Path -LiteralPath $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }
    $rand = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $baseName = [System.IO.Path]::GetFileName($InputFile)
    $tmpIn = Join-Path $tempDir "FileOptimizer_Input_${rand}_$baseName"
    $tmpOut = Join-Path $tempDir "FileOptimizer_Output_${rand}_$baseName"

    $sizeBefore = (Get-Item -LiteralPath $InputFile).Length
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    if ($sizeBefore -eq 0) {
        $sw.Stop()
        return @{
            ExitCode   = 0
            Skipped    = $true
            Reason     = 'ZeroByte'
            Accepted   = $false
            SizeBefore = 0
            SizeAfter  = 0
            DurationMs = $sw.ElapsedMilliseconds
        }
    }

    if (-not $Settings.Debug) {
        foreach ($t in @($tmpIn, $tmpOut)) {
            if (Test-Path -LiteralPath $t) { Remove-Item -LiteralPath $t -Force }
        }
    }

    $stepArgs = $Step.Arguments
    if ($null -eq $stepArgs) { $stepArgs = '' }
    $usesTmpOut = $stepArgs -and ($stepArgs -match '%TMPOUTPUTFILE%')
    $usesTmpInOnly = $stepArgs -and ($stepArgs -match '%TMPINPUTFILE%') -and -not $usesTmpOut -and ($stepArgs -notmatch '%OUTPUTFILE%')
    $usesInPlace = $Step.Mode -eq 'InPlace'
    if (-not $usesInPlace -and $stepArgs -and ($stepArgs -match '%INPUTFILE%') -and
        ($stepArgs -notmatch '%TMPOUTPUTFILE%') -and ($stepArgs -notmatch '%OUTPUTFILE%') -and
        ($stepArgs -notmatch '%TMPINPUTFILE%')) {
        $usesInPlace = $true
    }

    $inplaceBackup = $null
    $sizeAfter = $sizeBefore
    $exitCode = 0
    $exitOk = $false
    $reason = $null
    try {
        if ($usesInPlace) {
            $inplaceBackup = Join-Path $tempDir "FileOptimizer_inplacebak_${rand}_$baseName"
            Copy-Item -LiteralPath $InputFile -Destination $inplaceBackup -Force
        }

        if ($usesTmpInOnly -or ($Step.Handler -and $Step.Mode -eq 'TempInput')) {
            Copy-Item -LiteralPath $InputFile -Destination $tmpIn -Force
        }

        foreach ($requiredExe in (Get-FoStepRequiredExecutables -Step $Step)) {
            $toolCheck = Resolve-FoPluginExecutable -Name $requiredExe -SearchMode $SearchMode -PluginPath $PluginPath
            if (-not $toolCheck.Found) {
                return @{
                    ExitCode   = 1
                    Skipped    = $true
                    Reason     = 'ToolMissing'
                    Tool       = $requiredExe
                    Accepted   = $false
                    SizeBefore = $sizeBefore
                    SizeAfter  = $sizeBefore
                    DurationMs = $sw.ElapsedMilliseconds
                }
            }
        }

    if ($Step.Handler) {
        if (Test-FoDisablePluginMaskMatch -Mask $Settings.DisablePluginMask -Haystack $Step.Handler) {
            return @{
                ExitCode   = 0
                Skipped    = $true
                SizeBefore = $sizeBefore
                SizeAfter  = $sizeBefore
            }
        }

        $handlerTimeout = 0
        if ($null -ne $Settings.PluginTimeoutSeconds) {
            $handlerTimeout = [Math]::Max(0, [int]$Settings.PluginTimeoutSeconds)
        }
        $handlerExit = Invoke-FoNativeHandler -HandlerName $Step.Handler -InputPath $InputFile -OutputPath $tmpOut `
            -SearchMode $SearchMode -PluginPath $PluginPath -TimeoutSeconds $handlerTimeout
        if ($null -eq $handlerExit) {
            Write-Warning "Unknown handler '$($Step.Handler)' in step '$($Step.Name)'; treating as failure."
            $exitCode = 1
        }
        else {
            $exitCode = $handlerExit
        }

        if ($exitCode -eq -1) {
            # Timeout should not early-return: we still need in-place rollback + temp cleanup.
            $reason = 'Timeout'
        }
    }
    else {
        $argTemplate = $stepArgs
        $argTemplate = $argTemplate.Replace('%INPUTFILE%', (Format-FoProcessArgument $InputFile))
        $argTemplate = $argTemplate.Replace('%TMPINPUTFILE%', (Format-FoProcessArgument $tmpIn))
        $argTemplate = $argTemplate.Replace('%TMPOUTPUTFILE%', (Format-FoProcessArgument $tmpOut))
        $argTemplate = $argTemplate.Replace('%OUTPUTFILE%', '""')

        $maskHaystack = ($Step.Executable + ' ' + $argTemplate).Trim()
        if (Test-FoDisablePluginMaskMatch -Mask $Settings.DisablePluginMask -Haystack $maskHaystack) {
            return @{
                ExitCode   = 0
                Skipped    = $true
                SizeBefore = $sizeBefore
                SizeAfter  = $sizeBefore
            }
        }

        $resolved = Resolve-FoPluginExecutable -Name $Step.Executable -SearchMode $SearchMode -PluginPath $PluginPath
        $exePath = $resolved.Path
        $workDir = if ($resolved.Source -eq 'Portable' -and $PluginPath) { $PluginPath } else { Split-Path -Parent $exePath }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exePath
        $psi.Arguments = $argTemplate
        $psi.WorkingDirectory = $workDir
        $psi.UseShellExecute = $false
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $p = $null
        try {
            $p = [System.Diagnostics.Process]::Start($psi)
        }
        catch {
            $sw.Stop()
            return @{
                ExitCode   = 1
                Skipped    = $false
                Accepted   = $false
                Reason     = 'ProcessStartFailed'
                SizeBefore = $sizeBefore
                SizeAfter  = $sizeBefore
                DurationMs = $sw.ElapsedMilliseconds
            }
        }

        # Capture stderr asynchronously to avoid process deadlocks.
        # Note: we still read stderr into memory, but we will truncate it
        # to a configurable maximum before using/logging it.
        $stderrTask = $p.StandardError.ReadToEndAsync()

        $timeoutSec = 0
        if ($null -ne $Settings.PluginTimeoutSeconds) {
            $timeoutSec = [Math]::Max(0, [int]$Settings.PluginTimeoutSeconds)
        }

        $timedOut = $false
        if ($timeoutSec -gt 0) {
            $timeoutMs = $timeoutSec * 1000
            if (-not $p.WaitForExit($timeoutMs)) {
                $timedOut = $true
                try { $p.Kill() } catch { Write-Debug $_.Exception.Message }
                try { $p.WaitForExit(5000) } catch { Write-Debug $_.Exception.Message }
            }
        }
        else {
            $p.WaitForExit()
        }

        $stderr = $null
        try {
            $stderr = $stderrTask.GetAwaiter().GetResult()
        }
        catch { Write-Debug $_.Exception.Message }

        # Truncate stderr for safety (especially when LogLevel is high).
        $maxStderrBytes = 1048576
        if ($null -ne $Settings.MaxPluginStderrBytes) {
            $maxStderrBytes = [int64]$Settings.MaxPluginStderrBytes
        }
        if ($maxStderrBytes -lt 0) { $maxStderrBytes = 0 }
        if ($stderr -and $maxStderrBytes -gt 0) {
            $maxChars = [int64]([Math]::Floor($maxStderrBytes / 2))
            if ($stderr.Length -gt $maxChars) {
                $stderr = $stderr.Substring(0, [int]$maxChars) + '...(truncated)'
            }
        }

        if ($Settings.LogLevel -ge 3 -and $stderr) {
            Write-Verbose ("Plugin stderr ({0}): {1}" -f $Step.Name, $stderr.Trim())
        }

        $exitCode = if ($timedOut) { -1 } else { $p.ExitCode }
        $p.Dispose()

        if ($timedOut) {
            # Timeout should not early-return: we still need in-place rollback + temp cleanup.
            $reason = 'Timeout'
        }
    }

        $exitOk = Test-FoStepExitCodeAccepted -Step $Step -ExitCode $exitCode
    }
    catch {
        $sw.Stop()
        if ($usesInPlace -and $inplaceBackup -and (Test-Path -LiteralPath $inplaceBackup)) {
            Copy-Item -LiteralPath $inplaceBackup -Destination $InputFile -Force
        }
        return @{
            ExitCode   = 1
            Skipped    = $false
            Accepted   = $false
            Reason     = 'IOError'
            SizeBefore = $sizeBefore
            SizeAfter  = $sizeBefore
            DurationMs = $sw.ElapsedMilliseconds
        }
    }

    $sw.Stop()
    $accepted = $false

    if ($exitOk) {
        if ($usesInPlace) {
            $sizeAfter = (Get-Item -LiteralPath $InputFile).Length
            if ($sizeAfter -ge 8 -and $sizeAfter -lt $sizeBefore) {
                $accepted = $true
            }
        }
        elseif ($usesTmpOut -or $Step.Handler) {
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
    }

    if ($usesInPlace -and -not $accepted -and $inplaceBackup -and (Test-Path -LiteralPath $inplaceBackup)) {
        Copy-Item -LiteralPath $inplaceBackup -Destination $InputFile -Force
        $sizeAfter = $sizeBefore
    }

    if (-not $Settings.Debug) {
        foreach ($t in @($tmpIn, $tmpOut, $inplaceBackup)) {
            if ($t -and (Test-Path -LiteralPath $t)) { Remove-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue }
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
        Reason     = $reason
        SizeBefore = $sizeBefore
        SizeAfter  = $sizeAfter
        DurationMs = $sw.ElapsedMilliseconds
    }
}
