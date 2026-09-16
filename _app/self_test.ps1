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
  }
  else { Pass "PowerShell syntax $Relative" }
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
    $args = '/ErrorStdOut=UTF-8 /Validate "' + $path.Replace('"', '\"') + '"'
    $proc = Start-Process -FilePath $AhkPath -ArgumentList $args -WorkingDirectory $Root -Wait -PassThru `
      -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden
    $errText = if (Test-Path -LiteralPath $stderr) { [IO.File]::ReadAllText($stderr) } else { '' }
    $outText = if (Test-Path -LiteralPath $stdout) { [IO.File]::ReadAllText($stdout) } else { '' }
    if ($proc.ExitCode -ne 0) {
      $detail = (($errText + "`n" + $outText).Trim())
      if ([string]::IsNullOrWhiteSpace($detail)) { $detail = "exit code $($proc.ExitCode)" }
      Fail "AutoHotkey /Validate $Relative :: $detail"
    }
    else { Pass "AutoHotkey /Validate $Relative" }
  }
  catch {
    Fail "AutoHotkey /Validate $Relative :: $($_.Exception.Message)"
  }
  finally {
    Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
  }
}

$required = @(
  'StrategyEditorHost.ahk', 'ui\index.html', 'ui\styles.css', 'ui\spatial-actions.css', 'ui\app.js', 'ui\spatial-actions.js',
  'data\towers.ini', 'data\maps.ini', 'capture_roblox.ps1', 'sync_portraits.ps1',
  'calibration\sandbox_replay.ahk'
)
foreach ($rel in $required) { Test-RequiredFile $rel }

foreach ($rel in @('run_editor.ps1', 'self_test.ps1', 'capture_roblox.ps1', 'sync_portraits.ps1')) {
  Test-PowerShellSyntax $rel
}

Test-AhkSyntax 'StrategyEditorHost.ahk'
Test-AhkSyntax 'calibration\sandbox_replay.ahk'

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
  }
  else { Pass 'Calibration X/Y remain client-local' }
}

$node = Get-Command node.exe -ErrorAction SilentlyContinue
if (!$node) { $node = Get-Command node -ErrorAction SilentlyContinue }
if ($node) {
  try {
    & $node.Source --check $jsPath 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail 'JavaScript parser check failed' } else { Pass 'JavaScript syntax (node --check)' }
  }
  catch { Fail "JavaScript syntax check :: $($_.Exception.Message)" }
}
elseif (!$Quiet) {
  Write-Host '[INFO] Node.js not installed; skipped optional node --check.' -ForegroundColor DarkGray
}

$replayText = [IO.File]::ReadAllText((Join-Path $Root 'calibration\sandbox_replay.ahk'))
if ($replayText -match 'CoordMode\("Mouse",\s*"Screen"\)') { Fail 'Replay uses Screen mouse coordinates' } else { Pass 'Replay mouse coordinates are Client-local' }
if ($replayText -match '1339\s*,\s*236' -or $replayText -match '1200\s*,\s*2\s*,\s*"R"') { Fail 'Replay contains obsolete pre-v1.3 camera constants' } else { Pass 'Replay uses current relative camera sequence' }
if ($replayText -match '\[800,\s*1000\]') { Fail 'Replay contains obsolete fixed hotbar Y=1000 contract' } else { Pass 'Replay hotbar coordinates follow current macro contract' }
if ($replayText -notmatch 'SLE_HyperSleep\(750\)') { Fail 'Replay camera zoom does not use the macro-equivalent 750 ms HyperSleep' } else { Pass 'Replay camera zoom uses HyperSleep(750)' }
if ($replayText -notmatch 'PotatoMode') { Fail 'Replay does not mirror PotatoMode placement timing' } else { Pass 'Replay mirrors PotatoMode placement timing' }
if ($replayText -notmatch 'SLE_PlaceReplayTower' -or $replayText -notmatch 'SLE_BuildPlacementTargets' -or $replayText -notmatch 'maxPlacementAttempts := 9' -or $replayText -notmatch 'maxSameSpotRetries := 8') { Fail 'Replay bounded placement-recovery contract is incomplete' } else { Pass 'Replay bounded placement-recovery contract' }
if ($replayText -notmatch 'SLE_IsPlacementExplicitlyRejected' -or $replayText -notmatch 'cannot_place_here_v2\.png') { Fail 'Replay explicit space-rejection detection is incomplete' } else { Pass 'Replay explicit space-rejection detection' }
if ($replayText -notmatch 'SLE_ApplyPlacementSafePitch' -or $replayText -notmatch 'CAMERA_PITCH_RECOVERY' -or $replayText -notmatch 'Round\(rh \* 0\.03\)') { Fail 'Replay safe camera-pitch recovery is incomplete' } else { Pass 'Replay safe camera-pitch recovery' }
if ($replayText -notmatch 'if !cameraPitchRecovered' -or $replayText -notmatch 'cameraPitchRecovered := placement\.pitchRecovered') { Fail 'Replay camera-pitch recovery is not bounded to one adjustment per run' } else { Pass 'Replay camera-pitch recovery is bounded to one adjustment per run' }
if ($replayText -notmatch 'SLE_CloseTowerPanelIfOpen' -or $replayText -notmatch 'SLE_TowerPanelVisible') { Fail 'Replay tower-panel lifecycle cleanup is incomplete' } else { Pass 'Replay tower-panel lifecycle cleanup' }
if ($replayText -match 'SLE_WaitForTowerConfirmation\(contract\.root, hwnd, 1600\)') { Fail 'Replay still uses the old one-shot 1600ms placement confirmation' } else { Pass 'Replay no longer uses one-shot placement confirmation' }

$hostText = [IO.File]::ReadAllText((Join-Path $Root 'StrategyEditorHost.ahk'))
if ($hostText -notmatch 'SLE_HyperSleep\(750\)') { Fail 'Host camera alignment does not use HyperSleep(750)' } else { Pass 'Host camera alignment uses HyperSleep(750)' }
if ($hostText -notmatch 'SLE_ApplyMapCameraZoom\(hwnd, mapName\)' -or $replayText -notmatch 'SLE_ApplyMapCameraZoom\(hwnd, mapName\)' -or $replayText -notmatch 'replay\.mapName') { Fail 'Map specific camera zoom is not applied by both Strategy Lab camera paths' } else { Pass 'Strategy Lab camera paths apply the map specific zoom' }
if ($hostText -notmatch 'fallback-1920x1080') { Fail 'Host does not match New Era 1.3.4 no-metadata strategy fallback' } else { Pass 'New Era 1.3.4 no-metadata coordinate fallback is explicit' }
if ($hostText -notmatch 'SLE_ProjectionConfigValid' -or $hostText -notmatch 'PpuX0' -or $hostText -notmatch 'PpuY0') { Fail 'Host projected-ring calibration contract is incomplete' } else { Pass 'Host projected-ring calibration contract' }
if ($hostText -notmatch 'SLE_SaveGeometry' -or $hostText -notmatch 'SLE_WriteGeometryIni' -or $hostText -notmatch '"Geometry", "PixelsPerStud"') { Fail 'Host cannot persist a solved calibration geometry' } else { Pass 'Host persists solved calibration geometry' }
if ($hostText -notmatch 'SLE_WriteGeometryIni\(SLE_GeometryCalibrationPath\(""\), mapName, solve\)') { Fail 'A solved calibration is not shared with other maps' } else { Pass 'Solved calibration applies to every map' }
if ($hostText -notmatch 'rangeTop' -or $hostText -notmatch 'rangeBottom' -or $hostText -notmatch '"upgradePath"') { Fail 'Split-path attack range tracking is incomplete' } else { Pass 'Split-path attack range tracking' }
if ($hostText -notmatch 'SLE_ParseRangeValues') { Fail 'Tower catalog range parser is incomplete' } else { Pass 'Tower catalog range parser' }
if ($hostText -notmatch 'SLE_MapBackgroundPath' -or $hostText -notmatch 'SLE_AutoLoadMapBackground') { Fail 'Host map background provider chain is missing' } else { Pass 'Host map background provider chain' }
if ($hostText -match 'for\s+\w+\s+in\s+\d+\.\.') { Fail 'Host uses an AutoHotkey range operator that does not exist in v2' } else { Pass 'Host loops are valid AutoHotkey v2' }
if ($js -notmatch 'function projectionAt\(p\)' -or $js -notmatch 'const projection = projectionAt\(p\)' -or $js -notmatch 'function footprintSize\(p\)') { Fail 'Web renderer position-aware footprint projection is missing' } else { Pass 'Web renderer position-aware footprint projection' }
if ($js -notmatch 'function rangeStuds\(p\)' -or $js -notmatch 'function rangeSize\(p\)' -or $js -notmatch 'function buildRanges\(\)') { Fail 'Web renderer has no separate attack range layer' } else { Pass 'Web renderer attack range layer' }
if ($js -match 'radiusPx / ppu' -or $js -match 'footprintOverride = footprint;') { Fail 'Calibration still writes a measured range ring into the placement footprint' } else { Pass 'Calibration keeps range and footprint separate' }
if ($js -notmatch 'function pairCollides\(a, b\)' -or $js -notmatch 'distanceUnits < contactUnits - tolerance') { Fail 'Overlap detection does not use a footprint contact test' } else { Pass 'Overlap detection uses footprint contact distance' }
if ($js -match 'effectiveFootprint\(p\) \* projection' -or $js -match 'rangeStuds\(p\)[^)]*collision') { Fail 'Overlap detection is contaminated by attack range' } else { Pass 'Overlap detection ignores attack range' }

$towersIni = [IO.File]::ReadAllText((Join-Path $Root 'data\towers.ini'))
$towerSections = @([regex]::Matches($towersIni, '(?m)^\[(.+)\]\s*$') | ForEach-Object { $_.Groups[1].Value })
$rangeKeys = @([regex]::Matches($towersIni, '(?m)^range=(.*)$') | ForEach-Object { $_.Groups[1].Value })
if ($towerSections.Count -ne $rangeKeys.Count) { Fail "Tower catalog is missing range rows: $($towerSections.Count) towers, $($rangeKeys.Count) range entries" } else { Pass 'Tower catalog declares a range row per tower' }
$withRange = @($rangeKeys | Where-Object { $_ -match '^\d' }).Count
if ($withRange -lt ($towerSections.Count * 0.9)) { Fail "Only $withRange of $($towerSections.Count) towers have published range data" } else { Pass "Tower range data present for $withRange/$($towerSections.Count) towers" }
$dupTowers = @($towerSections | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
if ($dupTowers.Count) { Fail ('Duplicate tower catalog sections: ' + ($dupTowers -join ', ')) } else { Pass 'Tower catalog sections are unique' }
$enforcerBlock = [regex]::Match($towersIni, '(?ms)^\[Enforcer\]\s*(.*?)(?=^\[|\z)').Groups[1].Value
if ($enforcerBlock -notmatch 'wikiPage=Enforcer' -or $enforcerBlock -notmatch 'category=Evolved' -or $enforcerBlock -notmatch 'availability=current' -or $enforcerBlock -notmatch 'placementFootprint=1' -or $enforcerBlock -notmatch 'rangeTop=10,12,12,12,12,17,19\.5,19\.5' -or $enforcerBlock -notmatch 'rangeBottom=10,12,12,12,12,13,13,14') { Fail 'Enforcer evolved tower catalog support is incomplete' } else { Pass 'Enforcer evolved tower catalog support' }

if ($replayText -notmatch 'replay\.commands' -or $replayText -notmatch 'SLE_ExecuteUpgradeCommand' -or $replayText -notmatch 'SLE_ExecuteEnforcerReposition' -or $replayText -notmatch 'SLE_ExecuteEnforcerVan') { Fail 'Sandbox replay does not execute the supported strategy command sequence' } else { Pass 'Sandbox replay executes supported strategy commands in order' }
if ($replayText -notmatch 'bottomPath := \(command\.path = 2' -or $replayText -notmatch 'SLE_BuyOneUpgrade') { Fail 'Sandbox replay does not preserve split-path upgrade input' } else { Pass 'Sandbox replay preserves split-path upgrade input' }
if ($replayText -match 'SLE_UpgradePlacedTower\(contract\.root, hwnd, placement\.x' -or $replayText -notmatch 'SLE_OpenReplayTowerPanel') { Fail 'Sandbox replay upgrade lifecycle still re-clicks placements instead of executing explicit UpgradeTower commands' } else { Pass 'Sandbox replay opens one tower panel per grouped UpgradeTower command' }
if ($replayText -notmatch 'SLE_WaitForUpgradeAffordance' -or $replayText -notmatch 'SLE_UpgradeEvidenceDelta' -or $replayText -notmatch 'changedFrames >= 2') { Fail 'Sandbox replay upgrade confirmation is missing stable affordability/delta guards' } else { Pass 'Sandbox replay upgrade confirmation uses stable affordability and tolerant visual deltas' }
if ($js -notmatch 'function strategyReplayText\(\)[\s\S]{0,900}renderText\(\)' -or $js -match 'function strategyReplayText\(\)[\s\S]{0,900}lines\.push\([\s\S]{0,300}SpawnTower') { Fail 'Strategy Lab still reduces replay to generated SpawnTower-only text' } else { Pass 'Strategy Lab sends the complete edited strategy to Sandbox replay' }

$mainPath = Join-Path (Split-Path -Parent $Root) 'Main.ahk'
$mainText = if (Test-Path -LiteralPath $mainPath) { [IO.File]::ReadAllText($mainPath) } else { '' }
$upgradeRuntime = [regex]::Match($mainText, '(?ms)^UpgradeTower\(towerID,.*?(?=^UpgradePixelLooksEnabled\()').Value
$enforcerVanRuntime = [regex]::Match($mainText, '(?ms)^ActivateEnforcerVan\(wait := 0\).*?(?=^EnforcerVanOnCooldown\()').Value
if ($mainText -notmatch 'Hacker\|Enforcer\|EvolvedEnforcer' -or $mainText -notmatch 'Hacker/Enforcer = 5') { Fail 'Main runtime Enforcer split-path recognition is incomplete' } else { Pass 'Main runtime Enforcer split-path recognition' }
if ($mainText -notmatch 'ActivateEnforcerVan' -or $mainText -notmatch 'EnforcerReposition' -or $mainText -notmatch 'EnforcerVanKey') { Fail 'Main runtime Enforcer ability commands are incomplete' } else { Pass 'Main runtime Enforcer ability commands' }
if ($mainText -notmatch 'UpgradeButtonGreenCoverage' -or $mainText -notmatch 'greenSamples\+\+' -or $mainText -notmatch 'UpgradeButtonGreenCoverage\([^\r\n]+\) >= 8') { Fail 'Upgrade affordability guard does not require broad green coverage' } else { Pass 'Upgrade affordability guard requires broad green coverage' }
if ($mainText -match 'enabledColors := \[0x206435, 0x206235, 0x2B8046, 0x1D5930\]') { Fail 'Upgrade affordability guard still accepts a single matching green pixel' } else { Pass 'Single-pixel upgrade affordability gate removed' }
if ($mainText -notmatch 'UpgradeEvidenceDeltaCount' -or $mainText -notmatch 'delta >= 3' -or $mainText -notmatch 'changedFrames >= 2') { Fail 'Upgrade confirmation does not tolerate animated UI while requiring persistent visual change' } else { Pass 'Upgrade confirmation uses tolerant persistent visual deltas' }
if ($upgradeRuntime -match 'upgrade_retry' -or $upgradeRuntime -match 'continue[\s\S]{0,250}upgrade_ambiguous') { Fail 'Ambiguous upgrade input can still be blindly retried' } else { Pass 'Ambiguous upgrade input is never blindly retried' }
if ($mainText -notmatch 'MouseMove\(ScaleX\(unfocusX\), ScaleY\(unfocusY\), 0\)' -or $mainText -notmatch '0xF8F8F8' -or $mainText -notmatch 'xSamples := \[0\.06, 0\.13') { Fail 'Upgrade evidence is not hover-normalized and densely quantized' } else { Pass 'Upgrade evidence is hover-normalized and densely quantized' }
if ($upgradeRuntime -notmatch 'WaitForPersistentUpgradeEvidenceChange[\s\S]+Towers\[towerID\]\.level \+= 1[\s\S]+Towers\[towerID\]\.path := Integer\(path\)[\s\S]+Towers\[towerID\]\.pathLevel := effectivePathLevel') { Fail 'Confirmed split-path upgrades do not persist runtime path metadata after evidence validation' } else { Pass 'Confirmed split-path upgrades persist runtime path metadata' }
if ($upgradeRuntime -notmatch '\(path = 1 \|\| path = 2\)[\s\S]+Towers\[towerID\]\.level >= effectivePathLevel') { Fail 'Runtime path persistence is not restricted to a confirmed path branch' } else { Pass 'Runtime path persistence is restricted to the confirmed branch' }
if ($enforcerVanRuntime -notmatch 'waitMs := IsNumber\(wait\) \? Max\(0, Integer\(wait\)\) : 0' -or $enforcerVanRuntime -notmatch 'Sleep\(waitMs\)') { Fail 'SWAT Van wait is not normalized as non-negative milliseconds' } else { Pass 'SWAT Van wait uses non-negative milliseconds' }
if ($enforcerVanRuntime -match 'if \(LastOpenedTowerID != ""\)[\s\S]{0,180}Click\(ScaleX\(unfocusX\), ScaleY\(unfocusY\)\)') { Fail 'SWAT Van empty-space click still depends on cached tower selection state' } elseif ($enforcerVanRuntime -notmatch 'SendEvent\("\{" CancelPlacementKey "\}"\)[\s\S]{0,300}Click\(ScaleX\(unfocusX\), ScaleY\(unfocusY\)\)[\s\S]{0,220}LastOpenedTowerID := ""[\s\S]{0,300}SendEvent\("\{" EnforcerVanKey "\}"\)') { Fail 'SWAT Van does not unconditionally clear selection before sending its key' } else { Pass 'SWAT Van clears tower selection before every activation attempt' }

$spatialPath = Join-Path $Root 'ui\spatial-actions.js'
$spatialText = if (Test-Path -LiteralPath $spatialPath) { [IO.File]::ReadAllText($spatialPath) } else { '' }
if ($spatialText -notmatch 'CloneTower' -or $spatialText -notmatch 'BrawlerReposition' -or $spatialText -notmatch 'EnforcerReposition' -or $spatialText -notmatch 'rewriteLine') { Fail 'Strategy Lab spatial-action parser/rewriter is incomplete' } else { Pass 'Strategy Lab spatial-action parser/rewriter' }
if ($html -notmatch 'id="actionLayer"' -or $html -notmatch 'id="tabActions"' -or $html -notmatch 'id="actionRows"' -or $html -notmatch 'spatial-actions\.js' -or $html -notmatch 'Strategy Lab v4\.4') { Fail 'Strategy Lab v4.4 spatial-action UI shell is incomplete' } else { Pass 'Strategy Lab v4.4 spatial-action UI shell' }
if ($js -notmatch 'buildActionLayer' -or $js -notmatch 'selectAction' -or $js -notmatch 'moveAction' -or $js -notmatch 'StrategySpatial\.rewriteLine') { Fail 'Strategy Lab spatial-action visual editing is incomplete' } else { Pass 'Strategy Lab spatial-action visual editing' }

if ($mainText -notmatch 'ApplyRuntimePlacementSafePitch' -or $mainText -notmatch 'reposition_camera_pitch_recovery') { Fail 'Main runtime reposition camera recovery is missing' } else { Pass 'Main runtime reposition camera recovery' }
if ($mainText -notmatch 'swat_cooldown\.png' -or $mainText -notmatch 'helicopter_cooldown\.png' -or $mainText -notmatch 'helicopter_nocash\.png') { Fail 'Main runtime Enforcer ability error detection is incomplete' } else { Pass 'Main runtime Enforcer ability error detection' }
if ($js -notmatch "name: 'EnforcerReposition'" -or $js -notmatch "name: 'ActivateEnforcerVan'") { Fail 'Strategy Lab command reference is missing the Enforcer ability commands' } else { Pass 'Strategy Lab command reference documents the Enforcer ability commands' }
if ($mainText -notmatch 'wasRunning := IsSet\(RunningStrategy\)' -or $mainText -notmatch '!IsSet\(Recording\) \|\| !Recording') { Fail 'Main shutdown/recording VarUnset guards are missing' } else { Pass 'Main shutdown/recording VarUnset guards' }
$zoomTable = 'Map\("cataclysm", 1\)'
if ($mainText -notmatch $zoomTable -or $hostText -notmatch $zoomTable -or $replayText -notmatch $zoomTable) { Fail 'Macro, host and replay disagree about the map specific camera zoom table' } else { Pass 'Map specific camera zoom table matches across macro, host and replay' }
if ($mainText -notmatch 'ApplyMapCameraZoom\(\) >= 0') { Fail 'Cataclysm path does not apply the shared map camera zoom' } else { Pass 'Cataclysm path applies the shared map camera zoom' }
if ($html -notmatch 'Strategy Lab v4\.4' -or $html -notmatch 'pizzaroles24') { Fail 'Strategy Lab v4.4 credit/version marker is missing' } else { Pass 'Strategy Lab v4.4 credit/version marker' }

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
