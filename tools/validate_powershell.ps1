param(
    [string[]]$ScriptPath = @(
        'tools/sync_dependencies.ps1',
        'tools/validate_ahk.ps1',
        'submacros/safe_update.ps1',
        'tests/safe_updater_smoke.ps1'
    )
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

foreach ($script in $ScriptPath) {
    $resolved = [IO.Path]::GetFullPath((Join-Path $repoRoot $script))
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "PowerShell validation target does not exist: $resolved"
    }

    $tokens = $null
    $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile(
        $resolved,
        [ref]$tokens,
        [ref]$parseErrors
    )

    if ($parseErrors.Count -gt 0) {
        $details = ($parseErrors | ForEach-Object {
            "$($_.Extent.File):$($_.Extent.StartLineNumber): $($_.Message)"
        }) -join [Environment]::NewLine
        throw "PowerShell parse validation failed:`n$details"
    }

    Write-Host "PowerShell parse validation: PASS ($script)"
}
