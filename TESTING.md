# Testing guide

Automated checks do not launch Roblox, execute gameplay automation, or require
Discord credentials. Run the live scenarios separately with a disposable test
configuration.

## Automated preflight

Run from the repository root in PowerShell:

```powershell
pwsh ./tools/sync_dependencies.ps1
python -m py_compile tests/test_source_contracts.py tests/test_reported_runtime_fixes.py tests/validate_repo.py tests/lint_strategies.py
python tests/test_source_contracts.py .
python tests/test_reported_runtime_fixes.py .
python tests/validate_repo.py .
python tests/lint_strategies.py .
pwsh ./tools/validate_powershell.ps1
pwsh ./tests/safe_updater_smoke.ps1
pwsh ./tools/validate_ahk.ps1
```

The expected non-failing warning is:

- `3_JuggernautExp.strat` and `JuggernautExp.strat` currently have duplicate
  contents.

`sync_dependencies.ps1` creates ignored `lib/OCR.ahk` and `lib/JSON.ahk`
files from immutable, hash-verified sources. The CI workflow runs the same
preflight on Windows with read-only repository permissions.

## Manual runtime matrix

### Launch, configuration, and recording

1. Launch `Main.ahk` from a fresh release-style copy with webhooks and bot
   control disabled; confirm there is no AHK load error.
2. Save, restart, and verify `UpgradeDelay`, `UpgradeTowerGBKey`, and the other
   changed settings persist. Confirm the missing upgrade-key case falls back to
   `0` without an exception.
3. Record and reload a short strategy. Confirm the strategy editor remains
   aligned to the 1080-pixel strategy coordinate contract.

### Ready and image detection

1. Confirm the Ready action clicks the actual `ready_gs.png` match, not an
   unrelated green UI or map region.
2. Leave Ready visible once and confirm bounded retry; confirm a persistent
   Ready button causes safe recovery rather than an infinite loop.
3. Repeat with the Roblox window moved away from the monitor origin and at one
   non-default supported client size. Match coordinates must remain relative to
   the Roblox client while screen capture uses the window's screen origin.
4. Sanity-check two other image-driven actions such as Equip and Restart.
5. Confirm the native backend initializes with the required packaged DLLs. In a
   disposable release copy only, an explicit fallback test may temporarily
   remove the native DLLs and confirm the bounded GDI+ recovery path still
   starts; restore the files before package validation.

### Reported-bug regression matrix

1. Auto Equip: run at 1920x1080, then one non-default supported client size; verify the items/search/equip flow does not stall.
2. Matchmaking: run Easy and Frost. Frost must be selectable after bounded scrolling even if image matching misses; leaving the target unavailable must recover within 60 seconds.
3. Path tower: record Juggernaut **Bottom Path**, enter first path level **4**, replay, and confirm level 4 takes the bottom branch. Right-click the indicator and verify the path can be changed and re-saved.
4. DJ: record Green → Purple → Red changes and replay them; temporarily trigger the track cooldown and confirm the macro retries instead of silently continuing.
5. Cross-resolution: record raw Click + Clone + Brawler reposition at one supported client size and replay at another; destinations must remain aligned.
6. Move the Roblox window away from the desktop origin and verify Ready, map OCR/image check, reward OCR and disconnect handling still target Roblox.
7. Leave a normal match running after the final recorded step for >40 minutes; the watchdog must not restart it merely because the old broad playing phase expired.

### Strategy execution

1. Run at least one complete strategy from lobby through win/loss and
   post-match handling.
2. Exercise placement, upgrade, target, ability, skip, and sell commands where
   available.
3. Launch once from a Git checkout and once from a linked worktree; confirm no
   community request or strategy mutation occurs. Then confirm an extracted
   release copy downloads the official `Resources/Strats` manifest and leaves
   the prior managed set intact on a simulated partial or failed refresh.
4. Keep all three retired Frost strategies absent unless a developer/tester has
   supplied and validated a replacement official strategy.

### Pending input/runtime compatibility

1. Turn **Use Numbers for Hotbar** OFF and run `SpawnTower` with Soldier in slot
   1. Confirm the slot highlights, a placement ghost appears, the tower is
   placed, and its following upgrades complete. Repeat once after resizing or
   moving the Roblox window, and verify the runtime log records
   `hotbar_slot_resolved` with slot, x/y, and current client width/height.
2. With **Use Numbers for Hotbar** still OFF, record a slot-1 Soldier placement,
   save it, and replay it. Confirm recording and replay select the same hotbar
   slot dynamically and place at the intended client-relative coordinates.
3. Turn **Use Numbers for Hotbar** back ON and rerun the same strategy. Confirm
   keyboard selection remains unchanged and placement/upgrades still pass.
4. Run the same short smoke strategy under the bundled AutoHotkey 2.0.12 and
   the validation baseline 2.0.26. Record any parsing, timing, input, or image
   backend difference; this comparison is not settled by source validation.

### Webhook, bot, and watchdog

Use only disposable test credentials and remove them afterward.

1. Confirm a normal webhook screenshot arrives exactly once and no bitmap
   ownership error occurs.
2. Confirm queues smaller than 20 messages send after the collection window.
3. Exercise one bot screenshot command and verify exactly one attachment.
4. Simulate a transient network error, HTTP 429, and 5xx response where
   practical; retries must be bounded and use a fresh request lifecycle.
5. Exercise watchdog disconnect/result handling. Invalid result coordinates
   must return to fallback handling before OCR capture, and watchdog cleanup
   must not crash.

### Transactional updater

Use a disposable extracted release copy, never this Git checkout.

1. Confirm the updater reads releases from `DarksenDev/tds-macro` and does
   not offer a downgrade or same-version reinstall.
2. Confirm the chosen asset is `TDS_Macro.zip` and has a GitHub `sha256:`
   digest before accepting the prompt.
3. Complete one staged update and verify the new version launches, user
   strategies survive, and filename conflicts keep both user and release copies.
4. Verify the sibling rollback backup and
   `%APPDATA%\Ultimate_Macro\Logs\last-update-backup.txt`.
5. Confirm an invalid package fails before the old installation is moved and a
   directory containing `.git` is refused.

Record environment, commit/release version, Windows version, display scaling,
Roblox client size, backend, and observed results in the QA sign-off. Redact all
credentials and private links.
