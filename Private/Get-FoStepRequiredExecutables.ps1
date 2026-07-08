$script:FoNativeHandlerRegistry = @{
    DefluffPipe    = [PSCustomObject]@{
        Executables = @('defluff.exe')
        Invoke      = {
            param($InputPath, $OutputPath, $SearchMode, $PluginPath, $TimeoutSeconds)
            $exe = (Resolve-FoPluginExecutable -Name 'defluff.exe' -SearchMode $SearchMode -PluginPath $PluginPath).Path
            Invoke-FoDefluffPipe -InputPath $InputPath -OutputPath $OutputPath -DefluffExe $exe -TimeoutSeconds $TimeoutSeconds
        }
    }
    GzipRecompress = [PSCustomObject]@{
        Executables = @('gzip.exe')
        Invoke      = {
            param($InputPath, $OutputPath, $SearchMode, $PluginPath, $TimeoutSeconds)
            $exe = (Resolve-FoPluginExecutable -Name 'gzip.exe' -SearchMode $SearchMode -PluginPath $PluginPath).Path
            Invoke-FoGzipRecompress -InputPath $InputPath -OutputPath $OutputPath -GzipExe $exe -TimeoutSeconds $TimeoutSeconds
        }
    }
    JsMinPipe      = [PSCustomObject]@{
        Executables = @('jsmin.exe')
        Invoke      = {
            param($InputPath, $OutputPath, $SearchMode, $PluginPath, $TimeoutSeconds)
            $exe = (Resolve-FoPluginExecutable -Name 'jsmin.exe' -SearchMode $SearchMode -PluginPath $PluginPath).Path
            Invoke-FoJsMinPipe -InputPath $InputPath -OutputPath $OutputPath -JsMinExe $exe -TimeoutSeconds $TimeoutSeconds
        }
    }
    SqliteOptimize = [PSCustomObject]@{
        Executables = @('sqlite3.exe')
        Invoke      = {
            param($InputPath, $OutputPath, $SearchMode, $PluginPath, $TimeoutSeconds)
            $exe = (Resolve-FoPluginExecutable -Name 'sqlite3.exe' -SearchMode $SearchMode -PluginPath $PluginPath).Path
            Invoke-FoSqliteOptimize -InputPath $InputPath -OutputPath $OutputPath -SqliteExe $exe -TimeoutSeconds $TimeoutSeconds
        }
    }
}

function Get-FoNativeHandlerRegistry {
    return $script:FoNativeHandlerRegistry
}

function Get-FoStepRequiredExecutables {
    param($Step)
    if ($Step.Handler) {
        $entry = $script:FoNativeHandlerRegistry[$Step.Handler]
        if ($entry) { return @($entry.Executables) }
        return @()
    }
    if ($Step.Executable) {
        return @($Step.Executable)
    }
    return @()
}

function Invoke-FoNativeHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HandlerName,
        [Parameter(Mandatory)]
        [string]$InputPath,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [string]$SearchMode,
        [string]$PluginPath,
        [int]$TimeoutSeconds = 0
    )

    if (-not $script:FoNativeHandlerRegistry.ContainsKey($HandlerName)) {
        return $null
    }

    $entry = $script:FoNativeHandlerRegistry[$HandlerName]
    & $entry.Invoke $InputPath $OutputPath $SearchMode $PluginPath $TimeoutSeconds
}
