"""Focused static regression contracts for the adversarial stability audit.

These contracts exercise source-level invariants only. They do not claim live
Roblox or gameplay coverage.
"""
from pathlib import Path
import sys


def body(source: str, start: str, end: str) -> str:
    begin = source.find(start)
    finish = source.find(end, begin + len(start))
    if begin < 0 or finish < 0:
        raise AssertionError(f"missing function boundary: {start} -> {end}")
    return source[begin:finish]


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    main = (root / "Main.ahk").read_text(encoding="utf-8-sig")
    watchdog = (root / "submacros" / "watchdog.ahk").read_text(encoding="utf-8-sig")

    for name, end in [
        ("ChangeTargets(towerID, target) {", "CloneTower(towerId, x, y, wait := 0) {"),
        ("CloneTower(towerId, x, y, wait := 0) {", "BrawlerReposition(towerId, x, y) {"),
        ("BrawlerReposition(towerId, x, y) {", "ActivateRaiseTheDead(wait := 0) {"),
    ]:
        section = body(main, name, end)
        assert section.rstrip().endswith("return true\n}"), name

    play = body(main, "PlayStrategy() {", "\nExecuteStep(step) {")
    assert 'if (stepResult = false)' in play
    assert 'resultDeadline := A_TickCount + 7200000' in play
    assert play.count('StopStrategy(false)') >= 5

    execute = body(main, "ExecuteStep(step) {", "LowerGraphics() {")
    assert 'Sleep(strategySleepMs)' in execute and 'return true' in execute
    assert 'Commander := true' in execute and 'return true' in execute
    assert 'return SellTower(Trim(m[1]))' in execute

    upgrade = body(main, "UpgradeTower(towerID, skipOpen :=", "isDisconnected() {")
    assert 'global UseHForUpgrade, UpgradeTowerGKey, UpgradeTowerGBKey' in upgrade
    assert 'Integer(totalUpgrades) < 1' in upgrade
    assert 'if (upgradesDone >= totalUpgrades)' in upgrade
    assert 'fully_upgraded after " upgradesDone " upgrades' in upgrade
    assert 'Roblox lost focus before upgrade input' in upgrade

    reconnect = body(main, "TryReconnect() {", "CheckPopups(*) {")
    assert 'if (!budget.allowed)' in reconnect
    assert 'ReliabilityEndRecovery()' in reconnect

    spawn = body(main, "SpawnTower(X, Y, slotNumber, towerID) {", "SellTower(towerID) {")
    assert 'tower panel or explicit placement rejection' in spawn
    assert 'if (!rejected)' in spawn

    modifiers = body(main, "ApplyModifiers() {", "FindReadyButton(&foundX, &foundY) {")
    assert 'WaitForPartyAnchorAbsent("Resources\\\\searchbar_modifiers.png"' in modifiers

    timescale = body(main, "activateTimescale() {", "AlignCamera(move :=")
    assert 'confirmationDeadline := A_TickCount + 2500' in timescale
    assert 'confirmProbe := AdvancedImageSearch("Resources\\\\confirm.png"' in timescale

    run_strategy = body(main, 'RunStrategy(stratFile := "", skipRestart := false) {', "PlayStrategy() {")
    assert 'if (RunningStrategy != true)\n        return false' in run_strategy
    assert 'TimescaleActive := false' in run_strategy
    assert 'IsRestarting := false' in run_strategy
    assert 'needtocheckTowerUI := true' in run_strategy
    assert 'towerState.level := 0' in run_strategy
    assert 'Commander := false' in run_strategy and 'ActiveDJTrackRule := ""' in run_strategy

    check_restart = body(main, "CheckRestart() {", "RunRoblox(doReload := true) {")
    rewards_branch = body(check_restart, 'if (shouldCollectRewards && !MultiplayerEnabled) {', 'KillSubmacros()\n\n    if GetRobloxHWND()')
    assert 'KillSubmacros()' in rewards_branch
    fallback = check_restart[check_restart.rfind('IsRestarting := false'):]
    assert fallback.find('CloseRoblox()') >= 0
    assert fallback.find('startWatchdog()') < 0
    assert 'IsRestarting := false' in check_restart[check_restart.find('if !WaitForLobbyLoad()'):]

    assert '~F2:: StopStrategy(false)' in main

    launch = body(main, "RunRoblox(doReload := true) {", "ExitFullScreen() {")
    assert 'if !getRobloxPos(, , &w, &h)' in launch
    assert 'state=" stableSession.state' in body(main, "TryReconnect() {", "CheckPopups(*) {")

    load = body(main, "LoadStrategyFile(file) {", "RunStrategy(stratFile :=")
    assert 'strategy_width_invalid' in load and 'strategy_height_invalid' in load

    preflight = body(main, "RunPreflightCheck(stratFile) {", "StopStrategy(reload := true, *) {")
    assert 'strategy does not declare a map' in preflight.lower()
    assert 'strategy does not declare a difficulty' in preflight.lower()

    equip = body(main, "EquipTowers(towers) {", "CheckRestart() {")
    assert 'defaultTowerRemoved := false' in equip
    assert 'if (defaultTowerRemoved)' in equip
    assert 'if (A_TickCount - InnerStart > 3000)\n                break 2' in equip

    wave = body(main, "ReadCurrentWave() {", "CheckDJTrackSchedule() {")
    assert 'wave_ocr_implausible' in wave
    assert 'wave_ocr_stale_rejected' in wave
    assert 'return Integer(IniRead(StateFile, "State", "Wave", "0"))' not in wave

    auto_settings = (root / "lib" / "auto_settings.ahk").read_text(encoding="utf-8-sig")
    restore = auto_settings[auto_settings.find("WaitForRobloxExitAndRestore(expectedToken) {"):]
    assert 'restoreDeadline := A_TickCount + 300000' in restore
    assert 'AutoSettingsFail("Timed out waiting for Roblox to exit' in restore

    assert 'resultCandidate := ""' in watchdog
    assert 'resultSamples >= 2' in watchdog

    webhook = body(main, "PostWebhookDescription(url, description, color := 3447003, codeBlock := false) {",
                   "ProcessWebhookInstantQueue() {")
    assert 'return true\n}' in webhook
    assert '"step=" step' not in webhook

    print("stability audit contracts: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
