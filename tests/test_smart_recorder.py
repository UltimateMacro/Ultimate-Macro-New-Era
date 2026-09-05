"""Static contracts for the incremental smart recorder."""

from pathlib import Path
import re
import sys


def function_body(source: str, name: str) -> str:
    match = re.search(rf"(?ms)^\s*{re.escape(name)}\([^\n]*\)\s*\{{", source)
    if not match:
        raise AssertionError(f"missing function: {name}")
    start = match.end()
    depth = 1
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index]
    raise AssertionError(f"unterminated function: {name}")


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    source = (root / "Main.ahk").read_text(encoding="utf-8-sig")

    required = [
        "RecorderResetState()",
        "RecorderPushStep(",
        "RecorderFlagUncertain(",
        "RecorderNextTowerID(",
        "RecorderReview()",
        "ToggleRecordingPause(*)",
        "CancelRecording(*)",
        'global SmartRecorderEnabled := true, RecordingPaused := false',
        'Hotkey("~1", RecordHotbarSlot, "On")',
        'global RecSmartCtrl := MainGui.Add("Checkbox"',
        "RecPauseBtn.OnEvent(\"Click\", ToggleRecordingPause)",
        "ShowRecordingOverlay()",
        "HideRecordingOverlay()",
        "UpdateRecordingOverlay(*)",
        "SetTimer(UpdateRecordingOverlay, 100)",
        "RecorderObserveClick(",
        "RecorderVerifyObservedPlacement(*)",
        "RecorderObservePanelAction(",
        "RecorderVerifyObservedSell(*)",
        "RecorderRecordDJSchedule(",
        "RecorderCapturePlacementBaseline(",
        "RecorderPlacementRegionChanged(",
        "RecorderPlacementWasRejected()",
        "RecorderCancelPendingPlacement(",
        "RecSelectedCtrl",
        "RecNoticeCtrl",
        "djTrackSchedule=",
    ]
    missing = [token for token in required if token not in source]
    if missing:
        print("FAIL: missing recorder contract: " + ", ".join(missing))
        return 1
    if "IsSet(v.RecSmart)" in source:
        print("FAIL: IsSet was applied to a GUI object property")
        return 1

    active = function_body(source, "IsRecordingActive")
    if "RecordingPaused" not in active or "!RecordingPaused" not in active:
        print("FAIL: paused recording still accepts recording hotkeys")
        return 1

    placement = function_body(source, "SmartRecordPlacement")
    for token in ["RecorderSelectedSlot", "RecorderTowerNameForSlot", "RecorderNextTowerID", "RecorderPushStep", "openedSuccessfully",
                  "RecorderReleaseTowerID"]:
        if token not in placement:
            print(f"FAIL: smart placement is missing {token}")
            return 1
    if "InputBox" in placement:
        print("FAIL: smart placement asks for manual IDs")
        return 1
    if placement.index("if !openedSuccessfully") > placement.index("towerID := RecorderNextTowerID"):
        print("FAIL: smart placement allocates an ID before visual confirmation")
        return 1

    place_hotkey = function_body(source, "PlaceTowerHK")
    if "SmartRecordPlacement(mx, my)" not in place_hotkey or "InputBox" not in place_hotkey:
        print("FAIL: smart placement does not preserve the manual fallback")
        return 1

    upgrade = function_body(source, "UpgradeTowerHK")
    if "ActiveRTowerID" not in upgrade or "RecorderRecordUpgrade(closestID)" not in upgrade:
        print("FAIL: upgrade association does not prefer the selected recorded tower")
        return 1

    record_upgrade = function_body(source, "RecorderRecordUpgrade")
    if record_upgrade.index("RecorderPushStep") > record_upgrade.index("Towers[towerID].level += 1"):
        print("FAIL: recorder advances tower level before recording the upgrade step")
        return 1

    sell = function_body(source, "SellTowerHK")
    if "if SmartRecorderEnabled" not in sell or "if !SellTower(closestID)" not in sell:
        print("FAIL: smart sell does not require a successful runtime sell")
        return 1

    review = function_body(source, "RecorderReview")
    if "RecorderWarnings" not in review or "RecorderIsSupportedStep" not in review:
        print("FAIL: review does not expose/correct uncertain actions")
        return 1

    supported = function_body(source, "RecorderIsSupportedStep")
    for token in ["CloneTower", "BrawlerReposition"]:
        if token not in supported:
            print(f"FAIL: review does not accept existing command {token}")
            return 1

    observer = function_body(source, "RecorderObserveClick")
    for token in ["RecorderSelectedSlotAt", "RecorderPointNearTower", "SetTimer(RecorderVerifyObservedPlacement, -180)"]:
        if token not in observer:
            print(f"FAIL: placement observer is missing {token}")
            return 1

    placement_verify = function_body(source, "RecorderVerifyObservedPlacement")
    for token in ["waitForTowerUI", "pending.attempts", "RecorderPlacementWasRejected()",
                  "regionChanged", "RecorderFlagUncertain(\"placement\""]:
        if token not in placement_verify:
            print(f"FAIL: placement verification is missing {token}")
            return 1

    panel = function_body(source, "RecorderObservePanelAction")
    for token in ["RecorderFindClickedAsset", "ReadCurrentWave()", "RecorderRecordDJSchedule"]:
        if token not in panel:
            print(f"FAIL: panel observer is missing {token}")
            return 1

    sell_verify = function_body(source, "RecorderVerifyObservedSell")
    for token in ["waitForTowerUI", "SetTimer(RecorderVerifyObservedSell, -500)", "SellTower("]:
        if token not in sell_verify:
            print(f"FAIL: sell verification is missing {token}")
            return 1

    clone = function_body(source, "CloneTowerHK")
    for token in ["Towers.Has(towerID)", "if (!CloneTower(towerID, mx, my))", 'RecorderFlagUncertain("clone"', "RecorderPushStep("]:
        if token not in clone:
            print(f"FAIL: clone recording does not propagate runtime success: {token}")
            return 1

    brawler = function_body(source, "BrawlerRepositionHK")
    for token in ["if (!BrawlerReposition(towerID, mx, my))", 'RecorderFlagUncertain("brawler_reposition"', "RecorderPushStep("]:
        if token not in brawler:
            print(f"FAIL: brawler reposition recording does not propagate runtime success: {token}")
            return 1
    if 'RegExReplace(RepoKey' not in brawler:
        print("FAIL: non-recording Brawler reposition sends the wrong configured hotkey")
        return 1

    raise_dead = function_body(source, "ActivateRaiseTheDeadHK")
    for token in ["if (!ActivateRaiseTheDead(waitTime))", 'RecorderFlagUncertain("raise_dead"', "RecorderPushStep("]:
        if token not in raise_dead:
            print(f"FAIL: Raise the Dead recording does not propagate runtime success: {token}")
            return 1

    if "RecorderNextTowerID" in observer:
        print("FAIL: passive placement observer allocates IDs before verification")
        return 1
    if "RecorderNextTowerID" in placement_verify and "openedSuccessfully && regionChanged" not in placement_verify:
        print("FAIL: placement ID allocation is not gated by combined evidence")
        return 1

    if 'RecorderUsedTowerIDs[candidate] := true' not in source:
        print("FAIL: generated tower IDs are not reserved against reuse")
        return 1
    if 'RecorderFlagUncertain("placement"' not in placement:
        print("FAIL: failed/ambiguous placements are silently recorded")
        return 1

    print("smart recorder contracts: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
