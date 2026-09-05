"""Static contracts for the incremental reliability layer."""
from pathlib import Path
import sys


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    main_text = (root / "Main.ahk").read_text(encoding="utf-8-sig")
    reliability = (root / "lib" / "Reliability.ahk").read_text(encoding="utf-8-sig")
    required = [
        "ReliabilityFailure(", "ReliabilityLogFailure(", "ReliabilityBudget(",
        '"DETECTION_FAILURE"', '"ENVIRONMENT_INVALID"', '"TIMEOUT"',
    ]
    missing = [token for token in required if token not in reliability]
    if missing:
        print("FAIL: missing reliability contract: " + ", ".join(missing))
        return 1
    if "#Include lib\\Reliability.ahk" not in main_text:
        print("FAIL: reliability library is not included")
        return 1
    if 'ReliabilityLogFailure(result, "return_failure"' not in main_text:
        print("FAIL: migrated failure path has no structured logging")
        return 1
    if 'if (HasProp(result, "context") && result.context != "")' not in reliability:
        print("FAIL: failure logger must use HasProp for plain result objects")
        return 1
    if 'result.Has("context")' in reliability:
        print("FAIL: failure logger still calls Map.Has on a plain result object")
        return 1
    if main_text.count('ReliabilityBudget("waitForTowerUI"') != 1:
        print("FAIL: tower UI budget contract missing or duplicated")
        return 1
    for token in ["ReliabilityBeginRecovery(\"TryReconnect\")", "while (attempts < 3",
                  "DetectTdsSessionState()", "reconnect_unusable_state", "safe_reload_bypass"]:
        if token not in main_text:
            print(f"FAIL: missing reconnect safety contract: {token}")
            return 1
    if "i := success ? lookAhead : i + 1" in main_text:
        print("FAIL: UpgradeTower failure still advances the strategy")
        return 1
    if '"UpgradeTower failed; strategy execution stopped"' not in main_text:
        print("FAIL: UpgradeTower failure propagation contract missing")
        return 1
    if "return SelectMap(readyX, readyY)" in main_text:
        print("FAIL: SelectMap still recursively retries after prompt detection failure")
        return 1
    if 'ReliabilityFailure("DETECTION_FAILURE", "SelectMap"' not in main_text:
        print("FAIL: SelectMap detection failure is not classified")
        return 1
    for token in [
        'ReliabilityFailure("INTERACTION_FAILED", "SelectMap"',
        'result.expected := gamemap " selected"',
        'result.detector := "map-name OCR"',
        'result.detector := "StateManager transition detector"',
        'Play click did not produce a verified transition',
        'WaitForPartyAnchor("Resources\\\\type_to_search.png"',
        "VerifyPartySizeVisible(6000)",
        'WaitForPartyAnchorAbsent("Resources\\\\accept_invite.png"',
    ]:
        if token not in main_text:
            print(f"FAIL: SelectMap verification contract missing: {token}")
            return 1
    for token in [
        'ReliabilityFailure("DETECTION_FAILURE", "CreateParty"',
        'ReliabilityFailure("TIMEOUT", "CreateParty"',
        'ReliabilityFailure("DETECTION_FAILURE", "AcceptInvite"',
    ]:
        if token not in main_text:
            print(f"FAIL: party failure propagation contract missing: {token}")
            return 1
    for token in ["ReliabilityDetectState()", '"ROBLOX_CLOSED"', '"TDS_LOADING"',
                  '"MATCHMAKING"', '"MAP_SELECTION"', '"MAP_VOTING"', '"GAME_LOADING"',
                  '"IN_GAME"', '"DISCONNECTED"', '"UNKNOWN"',
                  "ReliabilityDetectStableState", "ReliabilityDetectBlocker", "BLOCKER_MODAL",
                  "state_anchor_conflict", "state_stability_timeout", "ReliabilityIsPlausibleLabel",
                  "ReliabilityPathBegin", "ReliabilityPathCheckpoint", "NAVIGATION_FAILED",
                  "drop_movement_key_once", "simulate_stuck_segment_once",
                  "focus_loss_once", "delay_key_release_once", "skip_checkpoint_once",
                  "checkpoint_never_once", "CataclysmPath()", "navigation_focus_lost",
                  "stale_checkpoint_once", "force_navigation_failure_once",
                  "ReliabilitySearchTemplate", "DetectionVariants",
                  'ReliabilityFailure("TIMEOUT", "SpawnTower"',
                  'ReliabilityFailure("DETECTION_FAILURE", "CheckTheMapF"',
                  "return ReliabilityPathFailure(pathOperation"]:
        if token not in reliability and token not in main_text:
            print(f"FAIL: state detector contract missing: {token}")
            return 1
    print("reliability foundation contracts: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
