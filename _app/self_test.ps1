param(
    [string]$Root = "",
    [string]$AhkPath = "",
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = [IO.Path]::GetFullPath($Root)
$failures = New-Object System.Collections.Generic.List[string]
$checks = New-Object System.Collections.Generic.List[string]

function Pass([string]$Text) {
    $checks.Add($Text)
    if (!$Quiet) { Write-Host ("[OK] " + $Text) -ForegroundColor Green }
}
function Fail([string]$Text) {
    $failures.Add($Text)
    Write-Host ("[FAIL] " + $Text) -ForegroundColor Red
}

function Test-RequiredFile([string]$Relative, [int]$MinimumBytes = 20) {
    $path = Join-Path $Root $Relative
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { Fail "Missing $Relative"; return }
    if ((Get-Item -LiteralPath $path).Length -lt $MinimumBytes) { Fail "$Relative is unexpectedly small"; return }
    Pass "File $Relative"
}

function Test-PowerShellSyntax([string]$Relative) {
    $path = Join-Path $Root $Relative
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { return }
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $details = ($errors | ForEach-Object { $_.Message }) -join '; '
        Fail "PowerShell syntax $Relative :: $details"
    } else { Pass "PowerShell syntax $Relative" }
}

function Test-AhkSyntax([string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($AhkPath) -or !(Test-Path -LiteralPath $AhkPath -PathType Leaf)) {
        Fail "AutoHotkey validator is unavailable for $Relative"
        return
    }
    $path = Join-Path $Root $Relative
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { return }
    $tag = [Guid]::NewGuid().ToString('N')
    $stdout = Join-Path $env:TEMP ("strategy-lab-ahk-$tag.out.txt")
    $stderr = Join-Path $env:TEMP ("strategy-lab-ahk-$tag.err.txt")
    try {
        $args = '/ErrorStdOut=UTF-8 /Validate "' + $path.Replace('"','\"') + '"'
        $proc = Start-Process -FilePath $AhkPath -ArgumentList $args -WorkingDirectory $Root -Wait -PassThru `
            -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden
        $errText = if (Test-Path -LiteralPath $stderr) { [IO.File]::ReadAllText($stderr) } else { '' }
        $outText = if (Test-Path -LiteralPath $stdout) { [IO.File]::ReadAllText($stdout) } else { '' }
        if ($proc.ExitCode -ne 0) {
            $detail = (($errText + "`n" + $outText).Trim())
            if ([string]::IsNullOrWhiteSpace($detail)) { $detail = "exit code $($proc.ExitCode)" }
            Fail "AutoHotkey /Validate $Relative :: $detail"
        } else { Pass "AutoHotkey /Validate $Relative" }
    } catch {
        Fail "AutoHotkey /Validate $Relative :: $($_.Exception.Message)"
    } finally {
        Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue
    }
}

$required = @(
    'StrategyEditorHost.ahk','ui\index.html','ui\styles.css','ui\app.js',
    'data\towers.ini','data\maps.ini','capture_roblox.ps1','sync_portraits.ps1',
    'calibration\sandbox_replay.ahk'
)
foreach ($rel in $required) { Test-RequiredFile $rel }

foreach ($rel in @('run_editor.ps1','self_test.ps1','capture_roblox.ps1','sync_portraits.ps1')) {
    Test-PowerShellSyntax $rel
}

Test-AhkSyntax 'StrategyEditorHost.ahk'
Test-AhkSyntax 'calibration\sandbox_replay.ahk'

# HTML/JS structural contract independent of Node.
$htmlPath = Join-Path $Root 'ui\index.html'
$jsPath = Join-Path $Root 'ui\app.js'
if ((Test-Path $htmlPath) -and (Test-Path $jsPath)) {
    $html = [IO.File]::ReadAllText($htmlPath)
    $js = [IO.File]::ReadAllText($jsPath)
    $ids = @([regex]::Matches($html, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    $duplicates = @($ids | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicates.Count) { Fail ('Duplicate HTML IDs: ' + ($duplicates -join ', ')) } else { Pass 'HTML IDs unique' }
    $refs = @([regex]::Matches($js, "\$\('([^']+)'\)") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    $missingRefs = @($refs | Where-Object { $_ -notin $ids })
    if ($missingRefs.Count) { Fail ('JavaScript references missing HTML IDs: ' + ($missingRefs -join ', ')) } else { Pass 'JavaScript/HTML ID contract' }

    if ($js -match 'clientX\s*\|\|\s*0\).*\+' -or $js -match 'imageX\s*\+\s*Number\(state\.calibration\.clientX') {
        Fail 'Calibration still adds screen client origin to .strat X/Y'
    } else { Pass 'Calibration X/Y remain client-local' }
}

# Optional full JS parser if Node happens to be installed.
$node = Get-Command node.exe -ErrorAction SilentlyContinue
if (!$node) { $node = Get-Command node -ErrorAction SilentlyContinue }
if ($node) {
    try {
        & $node.Source --check $jsPath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Fail 'JavaScript parser check failed' } else { Pass 'JavaScript syntax (node --check)' }
    } catch { Fail "JavaScript syntax check :: $($_.Exception.Message)" }
} elseif (!$Quiet) {
    Write-Host '[INFO] Node.js not installed; skipped optional node --check.' -ForegroundColor DarkGray
}

# Regression guards for the two bugs that reached Windows during alpha testing.
$replayText = [IO.File]::ReadAllText((Join-Path $Root 'calibration\sandbox_replay.ahk'))
if ($replayText -match 'CoordMode\("Mouse",\s*"Screen"\)') { Fail 'Replay uses Screen mouse coordinates' } else { Pass 'Replay mouse coordinates are Client-local' }
if ($replayText -match '1339\s*,\s*236' -or $replayText -match '1200\s*,\s*2\s*,\s*"R"') { Fail 'Replay contains obsolete pre-v1.3 camera constants' } else { Pass 'Replay uses current relative camera sequence' }
if ($replayText -match '\[800,\s*1000\]') { Fail 'Replay contains obsolete fixed hotbar Y=1000 contract' } else { Pass 'Replay hotbar coordinates follow current macro contract' }
if ($replayText -notmatch 'SLE_HyperSleep\(750\)') { Fail 'Replay camera zoom does not use the macro-equivalent 750 ms HyperSleep' } else { Pass 'Replay camera zoom uses HyperSleep(750)' }
if ($replayText -notmatch 'PotatoMode') { Fail 'Replay does not mirror PotatoMode placement timing' } else { Pass 'Replay mirrors PotatoMode placement timing' }

$hostText = [IO.File]::ReadAllText((Join-Path $Root 'StrategyEditorHost.ahk'))
if ($hostText -notmatch 'SLE_HyperSleep\(750\)') { Fail 'Host camera alignment does not use HyperSleep(750)' } else { Pass 'Host camera alignment uses HyperSleep(750)' }
if ($hostText -notmatch 'fallback-1920x1080') { Fail 'Host does not match New Era 1.3.4 no-metadata strategy fallback' } else { Pass 'New Era 1.3.4 no-metadata coordinate fallback is explicit' }
if ($hostText -notmatch 'SLE_ProjectionConfigValid' -or $hostText -notmatch 'PpuX0' -or $hostText -notmatch 'PpuY0') { Fail 'Host projected-ring calibration contract is incomplete' } else { Pass 'Host projected-ring calibration contract' }
if ($js -notmatch 'function projectionAt\(p\)' -or $js -notmatch 'Perspective is position-dependent') { Fail 'Web renderer position-aware footprint projection is missing' } else { Pass 'Web renderer position-aware footprint projection' }

# Developer-only projection fitter tests are intentionally skipped in the portable friend build.
# Python is not an editor runtime dependency.

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host ("Strategy Lab self-test FAILED: {0} issue(s)." -f $failures.Count) -ForegroundColor Red
    foreach ($item in $failures) { Write-Host (" - " + $item) -ForegroundColor Red }
    throw "Strategy Lab self-test failed with $($failures.Count) issue(s)."
}

if (!$Quiet) {
    Write-Host ''
    Write-Host ("Strategy Lab self-test passed: {0} checks." -f $checks.Count) -ForegroundColor Cyan
}
