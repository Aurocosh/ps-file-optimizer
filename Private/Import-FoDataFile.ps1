function Test-FoDataFileContentSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$tokens, [ref]$errors)

    if ($errors -and $errors.Count -gt 0) {
        throw "Data file parse error: $($errors[0].Message)"
    }

    $unsafe = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -or
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -or
        $node -is [System.Management.Automation.Language.SubExpressionAst] -or
        $node -is [System.Management.Automation.Language.UsingStatementAst] -or
        $node -is [System.Management.Automation.Language.TrapStatementAst] -or
        $node -is [System.Management.Automation.Language.DataStatementAst]
    }, $true)

    if ($unsafe -and $unsafe.Count -gt 0) {
        throw 'Data file contains executable content and cannot be loaded.'
    }

    return $true
}

function Import-FoDataFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Data file not found: $Path"
    }

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return Import-PowerShellDataFile -Path $Path
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $null = Test-FoDataFileContentSafe -Content $content
    $sb = [scriptblock]::Create($content)
    return & $sb
}
