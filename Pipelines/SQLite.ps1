function Get-FoSQLitePipeline {
    param([hashtable]$Context)
    $null = $Context  # Reserved pipeline-host signature

    $steps = @()
    $steps += New-FoStep -Name 'sqlite (1/1)' -Handler 'SqliteOptimize' -Mode TempOutput
    return $steps
}
