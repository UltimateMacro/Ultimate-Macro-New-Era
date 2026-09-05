"""Small source comparison contracts for v1.3.3 tower behavior.

These tests compare source semantics only. They do not execute Roblox.
"""
from pathlib import Path
import sys


def function_body(source: str, signature: str, end_signature: str) -> str:
    start = source.find(signature)
    if start < 0:
        raise AssertionError(f"missing function: {signature}")
    end = source.find(end_signature, start + len(signature))
    if end < 0:
        raise AssertionError(f"missing function boundary: {end_signature}")
    return source[start:end]


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    old_root = Path(r"C:\Users\aiden\Downloads\Ultimate Macro v1.3.3")
    current = (root / "Main.ahk").read_text(encoding="utf-8-sig")
    old = (old_root / "Main.ahk").read_text(encoding="utf-8-sig")

    current_upgrade = function_body(current, "UpgradeTower(towerID, skipOpen :=", "isDisconnected() {")
    old_upgrade = function_body(old, "UpgradeTower(towerID, skipOpen :=", "isDisconnected() {")

    # The old implementation escalated a missed tower UI directly into a
    # reload. The current path must keep the bounded classified failure.
    assert "SafeReload()" in old_upgrade
    assert "SafeReload()" not in current_upgrade
    assert "upgradeDeadline" in current_upgrade
    assert 'ReliabilityFailure("DETECTION_FAILURE", "UpgradeTower"' in current_upgrade

    # A fully-upgraded marker is not enough to satisfy a larger requested
    # count. This protects the level counter from silently skipping work.
    maxed = current_upgrade.find("fully_upgraded.png")
    assert maxed >= 0
    maxed_tail = current_upgrade[maxed:maxed + 1800]
    assert "upgradesDone >= totalUpgrades" in maxed_tail
    assert 'ReliabilityFailure("STRATEGY_FAILED", "UpgradeTower"' in maxed_tail
    assert "return false" in maxed_tail

    # Preserve the intentional path-branch correction rather than reverting to
    # v1.3.3's shared-level comparison.
    assert "nextLevel > pathLevel" in old_upgrade
    assert "IsPathSpecificUpgrade(towerID, nextLevel, path, effectivePathLevel)" in current_upgrade

    # Input alone must not advance the internal level. The current path must
    # first prove a changed upgrade region and a still-visible tower panel.
    verification_gate = current_upgrade.find("verifiedPanel := waitForTowerUI")
    level_increment = current_upgrade.find("Towers[towerID].level += 1")
    assert verification_gate >= 0
    assert level_increment > verification_gate
    assert "internal level was not advanced" in current_upgrade
    assert 'RuntimeLogInfo("upgrade_verified"' in current_upgrade
    assert 'resV2 := ""' in current_upgrade and 'resV1 := ""' in current_upgrade

    print("v1.3.3 regression contracts: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
