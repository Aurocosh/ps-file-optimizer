function Get-FoPipelineInventorySettings {
    [CmdletBinding()]
    param(
        [ValidateSet('32', '64')]
        [string]$Architecture = '64'
    )

    $s = Get-FoModuleDefaults
    $s.Level = 9
    $s.PNGAllowLossy = $true
    $s.JPEGAllowLossy = $true
    $s.JPEGCopyMetadata = $false
    $s.GIFAllowLossy = $true
    $s.WEBPAllowLossy = $true
    $s.EXEEnableUPX = $true
    $s.EXEDisablePETrim = $false
    $s.HTMLEnableTidy = $true
    $s.CSSEnableTidy = $true
    $s.JSEnableJSMin = $true
    $s.XMLEnableLeanify = $true
    $s.LUAEnableLeanify = $true
    $s.MiscDisable = $false
    $s.PDFSkipLayered = $false
    $s.PDFProfile = 'none'
    $s.ZIPRecurse = $true
    $s.GZCopyMetadata = $false
    $s.ZIPCopyMetadata = $false

    if ($script:FoModuleRoot) {
        $folder = if ($Architecture -eq '64') { 'Plugins64' } else { 'Plugins32' }
        $s.PluginPath = Join-Path $script:FoModuleRoot $folder
    }

    return $s
}

function Get-FoPipelineGroupPrimaryExtensions {
    [CmdletBinding()]
    param()

    if ($script:FoPipelineGroupPrimaryExtensions) {
        return $script:FoPipelineGroupPrimaryExtensions
    }

    $byGroup = @{}
    $map = Get-FoExtensionMap
    foreach ($ext in $map.Keys) {
        foreach ($group in @($map[$ext])) {
            if (-not $byGroup.ContainsKey($group)) {
                $byGroup[$group] = $ext
            }
        }
    }

    $script:FoPipelineGroupPrimaryExtensions = $byGroup
    return $byGroup
}

function New-FoPipelineInventoryContext {
    [CmdletBinding()]
    param(
        [string]$Extension = '.bin',
        [hashtable]$Flags = @{},
        [ValidateSet('32', '64')]
        [string]$Architecture = '64'
    )

    $settings = Get-FoPipelineInventorySettings -Architecture $Architecture
    $ctx = @{
        InputFile     = "C:\FoInventory\sample$Extension"
        Extension     = $Extension
        Settings      = $settings
        IsAPNG        = $false
        IsPNG9Patch   = $false
        IsZipSFX      = $false
        IsEXESFX      = $false
        IsJPEGCMYK    = $false
        IsPDFLayered  = $false
    }

    foreach ($key in $Flags.Keys) {
        $ctx[$key] = $Flags[$key]
    }

    if ($Flags.ContainsKey('Extension')) {
        $ctx.Extension = $Flags.Extension
        $ctx.InputFile = "C:\FoInventory\sample$($Flags.Extension)"
    }

    return $ctx
}

function Get-FoPipelineInventoryFlagVariants {
    [CmdletBinding()]
    param()

    return @(
        @{}
        @{ IsAPNG = $true }
        @{ IsPNG9Patch = $true }
        @{ IsPDFLayered = $true }
        @{ IsJPEGCMYK = $true }
    )
}

function Get-FoPipelineDeclaredExecutables {
    [CmdletBinding()]
    param(
        [ValidateSet('32', '64')]
        [string]$Architecture = $(if ([Environment]::Is64BitProcess) { '64' } else { '32' })
    )

    $exes = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $groupExtensions = Get-FoPipelineGroupPrimaryExtensions
    $flagVariants = Get-FoPipelineInventoryFlagVariants

    $pipelineCommands = @(Get-Command -Name 'Get-Fo*Pipeline' -CommandType Function -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^Get-Fo.+Pipeline$' })

    foreach ($cmd in $pipelineCommands) {
        if ($cmd.Name -notmatch '^Get-Fo(.+)Pipeline$') { continue }
        $group = $Matches[1]
        $ext = if ($groupExtensions.ContainsKey($group)) { $groupExtensions[$group] } else { '.bin' }

        foreach ($flags in $flagVariants) {
            $ctx = New-FoPipelineInventoryContext -Extension $ext -Flags $flags -Architecture $Architecture
            try {
                $steps = @(& $cmd.Name $ctx)
            }
            catch {
                Write-Warning "Pipeline inventory skipped $($cmd.Name): $($_.Exception.Message)"
                Write-Verbose "Pipeline inventory skipped $($cmd.Name) for variant: $($_.Exception.Message)"
                continue
            }

            foreach ($step in $steps) {
                foreach ($exe in (Get-FoStepRequiredExecutables -Step $step)) {
                    if ($exe) { [void]$exes.Add($exe) }
                }
            }
        }
    }

    return @($exes | Sort-Object)
}
