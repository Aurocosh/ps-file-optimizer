function Test-FoPathHasWildcard {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrEmpty($Path)) { return $false }
    foreach ($ch in $Path.ToCharArray()) {
        if ($ch -eq '*' -or $ch -eq '?' -or $ch -eq '[') { return $true }
    }
    return $false
}

function Get-FoTargetFiles {
    param(
        [string[]]$Path,
        [switch]$Recurse
    )

    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($p in $Path) {
        if (-not $p) { continue }
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)

        if (Test-FoPathHasWildcard -Path $resolved) {
            $params = @{ Path = $resolved; File = $true; ErrorAction = 'SilentlyContinue' }
            if ($Recurse) { $params.Recurse = $true }
            $matched = @(Get-ChildItem @params)
            if ($matched.Count -eq 0) {
                Write-Warning "No files matched: $p"
            }
            else {
                foreach ($item in $matched) { $files.Add($item.FullName) }
            }
            continue
        }

        if (Test-Path -LiteralPath $resolved -PathType Container) {
            $params = @{ LiteralPath = $resolved; File = $true; ErrorAction = 'SilentlyContinue' }
            if ($Recurse) { $params.Recurse = $true }
            Get-ChildItem @params | ForEach-Object { $files.Add($_.FullName) }
        }
        elseif (Test-Path -LiteralPath $resolved -PathType Leaf) {
            $files.Add($resolved)
        }
        else {
            Write-Warning "Path not found: $p"
        }
    }
    return @($files | Select-Object -Unique)
}
