@{
    # PSScriptAnalyzer settings for ps-file-optimizer (Gallery prep).
    # Run: Invoke-ScriptAnalyzer -Path .\Public,.\Private,.\Pipelines,.\Scripts -Settings .\PSScriptAnalyzerSettings.psd1 -Recurse
    Severity            = @('Error', 'Warning')
    IncludeDefaultRules = $true

    # Policy noise accepted for this CLI module (see code-review review--2026-07-24--psscriptanalyzer).
    ExcludeRules        = @(
        'PSAvoidUsingWriteHost'              # Intentional CLI / CI host output
        'PSUseSingularNouns'                # Plural nouns are intentional (Plugins, Flags, Steps, …)
        'PSUseBOMForUnicodeEncodedFile'     # UTF-8 without BOM is project encoding policy
        'PSUseShouldProcessForStateChangingFunctions'  # Private New-* / factory helpers are in-memory
    )
}
