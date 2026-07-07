$script:FoHandlerExecutables = @{
    DefluffPipe    = @('defluff.exe')
    GzipRecompress = @('gzip.exe')
    JsMinPipe      = @('jsmin.exe')
    SqliteOptimize = @('sqlite3.exe')
}

function Get-FoStepRequiredExecutables {
    param($Step)
    if ($Step.Handler) {
        return $script:FoHandlerExecutables[$Step.Handler]
    }
    if ($Step.Executable) {
        return @($Step.Executable)
    }
    return @()
}
