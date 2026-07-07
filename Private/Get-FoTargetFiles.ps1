function Get-FoTargetFiles {
    param(
        [string[]]$Path,
        [switch]$Recurse
    )

    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($p in $Path) {
        if (-not $p) { continue }
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
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
