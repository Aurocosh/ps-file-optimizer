$script:FoNativeHandlerRegistry = @{
    DefluffPipe    = @('defluff.exe')
    GzipRecompress = @('gzip.exe')
    JsMinPipe      = @('jsmin.exe')
    SqliteOptimize = @('sqlite3.exe')
}

function Get-FoNativeHandlerRegistry {
    return $script:FoNativeHandlerRegistry
}

function Get-FoStepRequiredExecutables {
    param($Step)
    if ($Step.Handler) {
        return $script:FoNativeHandlerRegistry[$Step.Handler]
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

    switch ($HandlerName) {
        'DefluffPipe' {
            $exe = (Resolve-FoPluginExecutable -Name 'defluff.exe' -SearchMode $SearchMode -PluginPath $PluginPath).Path
            return (Invoke-FoDefluffPipe -InputPath $InputPath -OutputPath $OutputPath -DefluffExe $exe -TimeoutSeconds $TimeoutSeconds)
        }
        'GzipRecompress' {
            $exe = (Resolve-FoPluginExecutable -Name 'gzip.exe' -SearchMode $SearchMode -PluginPath $PluginPath).Path
            return (Invoke-FoGzipRecompress -InputPath $InputPath -OutputPath $OutputPath -GzipExe $exe -TimeoutSeconds $TimeoutSeconds)
        }
        'JsMinPipe' {
            $exe = (Resolve-FoPluginExecutable -Name 'jsmin.exe' -SearchMode $SearchMode -PluginPath $PluginPath).Path
            return (Invoke-FoJsMinPipe -InputPath $InputPath -OutputPath $OutputPath -JsMinExe $exe -TimeoutSeconds $TimeoutSeconds)
        }
        'SqliteOptimize' {
            $exe = (Resolve-FoPluginExecutable -Name 'sqlite3.exe' -SearchMode $SearchMode -PluginPath $PluginPath).Path
            return (Invoke-FoSqliteOptimize -InputPath $InputPath -OutputPath $OutputPath -SqliteExe $exe -TimeoutSeconds $TimeoutSeconds)
        }
    }

    return $null
}
