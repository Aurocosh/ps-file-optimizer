function Write-FoLog {
    [CmdletBinding()]
    param(
        [int]$LogLevel = 1,
        [int]$RequiredLevel = 1,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',
        [string]$Message
    )

    if ($LogLevel -lt $RequiredLevel) { return }

    switch ($Level) {
        'Warning' { Write-Warning $Message }
        'Error'   { Write-Error $Message }
        'Debug'   { Write-Debug $Message }
        default   { Write-Host $Message }
    }
}
