from pathlib import Path
import re

main_path = Path("Main.ahk")
text = main_path.read_text(encoding="utf-8-sig")

old_pre = '''        isGreen := HasStableUpgradeAffordance(XA, YA, X2, Y2)
        if (isGreen && canBeUpgraded) {
            beforeEvidence := CaptureUpgradeEvidence(XA, YA, WA, HA)
            canUseAbility := false
'''
new_pre = '''        isGreen := HasStableUpgradeAffordance(XA, YA, X2, Y2)
        if (isGreen && canBeUpgraded) {
            ; Normalize pointer state before taking evidence. A click-hover transition must
            ; never be mistaken for a successful upgrade.
            if (!UseHForUpgrade) {
                MouseMove(ScaleX(unfocusX), ScaleY(unfocusY), 0)
                Sleep(80)
            }
            beforeEvidence := CaptureUpgradeEvidence(XA, YA, WA, HA)
            canUseAbility := false
'''
if old_pre not in text:
    raise SystemExit("pre-upgrade evidence block not found")
text = text.replace(old_pre, new_pre, 1)

old_post = '''            settleDelay := Max(250, IsNumber(UpgradeDelay) ? Integer(UpgradeDelay) : 250)
            Sleep(settleDelay)
            needtocheckTowerUI := true

            verifiedResV2 := ""
    verifiedResV1 := ""
    uiVerified := waitForTowerUI(&verifiedResV2, &verifiedResV1, 1000)
    evidenceChanged := uiVerified
        && WaitForPersistentUpgradeEvidenceChange(XA, YA, WA, HA, beforeEvidence, 1800)

    if (!evidenceChanged) {
        if (upgradeActionAttempts < 1 && HasStableUpgradeAffordance(XA, YA, X2, Y2)) {
            upgradeActionAttempts++
            RuntimeLogWarn("upgrade_retry", "Upgrade was not persistently confirmed; retrying once within bounded budget",
                "tower=" towerID "; next_level=" nextLevel "; attempt=" upgradeActionAttempts)
            canUseAbility := true
            needtocheckTowerUI := true
            Sleep(350)
            continue
        }

        LogToConsole("Tower " towerID " upgrade was not persistently confirmed; refusing to advance internal state.", true)
        RuntimeLogWarn("upgrade_ambiguous", "Upgrade input did not produce persistent post-action evidence",
            "tower=" towerID "; next_level=" nextLevel)
        canUseAbility := true
        return false
    }

    upgradeActionAttempts := 0
'''
new_post = '''            settleDelay := Max(250, IsNumber(UpgradeDelay) ? Integer(UpgradeDelay) : 250)
            Sleep(settleDelay)
            needtocheckTowerUI := true

            if (!UseHForUpgrade) {
                MouseMove(ScaleX(unfocusX), ScaleY(unfocusY), 0)
                Sleep(80)
            }

            verifiedResV2 := ""
            verifiedResV1 := ""
            uiVerified := waitForTowerUI(&verifiedResV2, &verifiedResV1, 1000)
            evidenceChanged := uiVerified
                && WaitForPersistentUpgradeEvidenceChange(XA, YA, WA, HA, beforeEvidence, 1800)

            if (!evidenceChanged) {
                if (upgradeActionAttempts < 1 && HasStableUpgradeAffordance(XA, YA, X2, Y2)) {
                    upgradeActionAttempts++
                    RuntimeLogWarn("upgrade_retry", "Upgrade was not persistently confirmed; retrying once within bounded budget",
                        "tower=" towerID "; next_level=" nextLevel "; attempt=" upgradeActionAttempts)
                    canUseAbility := true
                    needtocheckTowerUI := true
                    Sleep(350)
                    continue
                }

                LogToConsole("Tower " towerID " upgrade was not persistently confirmed; refusing to advance internal state.", true)
                RuntimeLogWarn("upgrade_ambiguous", "Upgrade input did not produce persistent post-action evidence",
                    "tower=" towerID "; next_level=" nextLevel)
                canUseAbility := true
                return false
            }

            upgradeActionAttempts := 0
'''
if old_post not in text:
    raise SystemExit("post-upgrade confirmation block not found")
text = text.replace(old_post, new_post, 1)

helpers = re.compile(
    r"WaitForPersistentUpgradeEvidenceChange\(x, y, w, h, beforeEvidence, timeoutMs := 1800\) \{.*?\n\}\n\n"
    r"CaptureUpgradeEvidence\(x, y, w, h\) \{.*?\n\}\n",
    re.S,
)
new_helpers = '''WaitForPersistentUpgradeEvidenceChange(x, y, w, h, beforeEvidence, timeoutMs := 1800) {
    if (beforeEvidence = "")
        return false

    deadline := A_TickCount + Max(400, timeoutMs)
    candidateEvidence := ""
    stableFrames := 0

    loop {
        evidence := CaptureUpgradeEvidence(x, y, w, h)
        if (evidence != "" && evidence != beforeEvidence) {
            if (evidence = candidateEvidence) {
                stableFrames++
            } else {
                candidateEvidence := evidence
                stableFrames := 1
            }

            ; Require a changed state to settle, rather than accepting one-frame
            ; hover/animation noise as proof that the upgrade happened.
            if (stableFrames >= 3)
                return true
        } else {
            candidateEvidence := ""
            stableFrames := 0
        }

        if (A_TickCount >= deadline)
            break
        Sleep(120)
    }
    return false
}

CaptureUpgradeEvidence(x, y, w, h) {
    if (w <= 0 || h <= 0)
        return ""

    ; Dense sampling makes price/label changes visible without depending on one
    ; exact pixel. Quantizing the RGB sample filters tiny antialiasing noise.
    xSamples := [0.06, 0.13, 0.20, 0.27, 0.34, 0.42, 0.50, 0.58, 0.66, 0.73, 0.80, 0.87, 0.94]
    ySamples := [0.08, 0.22, 0.36, 0.50, 0.64, 0.78, 0.92]
    evidence := ""

    for yRatio in ySamples {
        for xRatio in xSamples {
            try {
                color := PixelGetColor(x + Round(w * xRatio), y + Round(h * yRatio), "RGB")
                evidence .= (color & 0xF8F8F8) "|"
            } catch Error {
                return ""
            }
        }
    }
    return evidence
}
'''
text, count = helpers.subn(new_helpers, text, count=1)
if count != 1:
    raise SystemExit(f"expected one evidence helper pair, replaced {count}")

main_path.write_text(text, encoding="utf-8-sig")

test_path = Path("_app/self_test.ps1")
tests = test_path.read_text(encoding="utf-8-sig")
old_test = "if ($mainText -notmatch 'WaitForPersistentUpgradeEvidenceChange' -or $mainText -notmatch 'changedFrames >= 4' -or $mainText -notmatch 'upgrade was not persistently confirmed') { Fail 'Upgrade confirmation does not require persistent post-action evidence' } else { Pass 'Upgrade confirmation requires persistent post-action evidence' }"
new_test = "if ($mainText -notmatch 'WaitForPersistentUpgradeEvidenceChange' -or $mainText -notmatch 'stableFrames >= 3' -or $mainText -notmatch 'candidateEvidence' -or $mainText -notmatch 'upgrade was not persistently confirmed') { Fail 'Upgrade confirmation does not require stable post-action evidence' } else { Pass 'Upgrade confirmation requires stable post-action evidence' }"
if old_test not in tests:
    raise SystemExit("persistent evidence self-test not found")
tests = tests.replace(old_test, new_test, 1)

marker = "if ($mainText -notmatch 'upgradeActionAttempts < 1') { Fail 'Unconfirmed upgrade retry budget is not bounded to one retry' } else { Pass 'Unconfirmed upgrade retry budget is bounded' }\n"
addition = "if ($mainText -notmatch 'MouseMove\\(ScaleX\\(unfocusX\\), ScaleY\\(unfocusY\\), 0\\)' -or $mainText -notmatch '0xF8F8F8' -or $mainText -notmatch 'xSamples := \\[0\\.06, 0\\.13') { Fail 'Upgrade evidence is not hover-normalized and densely quantized' } else { Pass 'Upgrade evidence is hover-normalized and densely quantized' }\n"
if marker not in tests:
    raise SystemExit("retry-budget self-test marker not found")
if "Upgrade evidence is hover-normalized and densely quantized" not in tests:
    tests = tests.replace(marker, marker + addition, 1)
test_path.write_text(tests, encoding="utf-8-sig")
