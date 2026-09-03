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

### Persistent logs

Logs live in `%APPDATA%\Ultimate_Macro\Logs`. Session files are still written per
run and pruned after 14 days; `ultimate-macro.log` is the persistent store that
every component and every run appends to, capped at 2 MB with one previous
generation kept as `ultimate-macro.previous.log`.

1. Run a short strategy, close the macro, and reopen it. Confirm the console
   lines from the earlier run are still in `ultimate-macro.log`, and that the
   watchdog's lines appear there too under its own component name.
2. Confirm no webhook URL or bot token reaches either file. Console lines go
   through the same redaction as structured events.
3. Press Clear Logs in Settings, confirm the prompt, and verify the whole
   directory is emptied apart from the fresh `logs_cleared` entry. Logging must
   keep working afterwards without a restart.
4. Cancel the prompt instead and confirm nothing is deleted.

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

### Watchdog PID lifecycle

1. With TimeScale OFF, start a normal strategy and stop it. Repeat at least
   three times and confirm there is no `VarUnset` dialog and at most one
   watchdog process for this checkout remains while the strategy is running.
2. Repeat with TimeScale 2x. Exercise Restart, Play Again, and reconnect paths
   where practical; these transitions must not change TimeScale behavior or
   accumulate watchdog processes.
3. Close Main while a strategy is active. Confirm its watchdog exits and that a
   watchdog launched from a different checkout or extracted release is not
   terminated.
4. Inspect `%APPDATA%\Ultimate_Macro\Logs\ultimate-macro.log`. Normal cycles
   should show `watchdog_started` and `watchdog_stopped`. Capture any
   `watchdog_start_failed`, `watchdog_cleanup_failed`,
   `watchdog_cleanup_scan_failed`, or `watchdog_exit_cleanup_failed` event with
   its details if a failure occurs.

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

## Ziadod positive-backport QA

Run this after the normal automated suite and before promoting the runtime candidate:

1. **Party OFF baseline** — run a normal solo strategy and confirm matchmaking/abilities/watchdog are unchanged.
2. **Party validation** — enable Party Mode with missing Member host, missing Host members, and 4 members; each must be blocked before Roblox automation begins.
3. **Host + 1 member** — create/invite/join, confirm no cancel-invite race while names are being typed, and verify the host proceeds only after the configured member is present.
4. **Member path** — accept a host invite and confirm the 3-minute timeout reloads cleanly when no invite arrives.
5. **Rotation UI** — enabling rotation must lock Auto Equip ON; disabling rotation must make it editable again.
6. **Strategy scrollbar** — wheel scroll still works; dragging/clicking the thumb moves the card list without dragging the main window.
7. **Webhook validation** — typing a webhook does not perform a request on every character; invalid links keep Enable Webhook locked off and a valid webhook unlocks it.
8. **Discord Bot regression** — Bot tab, Test Bot, save, and remote-command settings remain present.
9. **Action buttons** — Start/Stop/Record/Party/Webhook/Bot/Settings buttons show/hover correctly; disabled Record Stop cannot fire.
10. **Held-input cleanup** — stop during movement/camera/recording and verify no mouse button, WASD, Shift, Ctrl, arrows, or raw scan-code movement remains held.
11. **Auto Settings opt-in/lifecycle** — a fresh Settings.tds must leave Auto Configure Settings OFF. Enabling it while idle must not change Roblox XML; starting a run must create `.macro_bak` plus `.macro_bak.meta` and apply exactly once immediately before Roblox launches.
12. **Auto Settings verified restore** — disable while Roblox is running. The verified backup must remain until `RobloxPlayerBeta.exe` exits, then the original SHA-256-identical XML must be restored before the backup and metadata are removed.
13. **Auto Settings unknown backup** — in a disposable fixture only, present a legacy `.macro_bak` without `.macro_bak.meta`. Confirm the macro refuses to apply/restore/delete it and reports the provenance failure.
14. **Auto Settings re-enable race** — disable with Roblox open, then re-enable before Roblox exits and launch a new run. Confirm the older helper generation exits without restoring over the new applied state.
15. **Auto Settings changed-current guard** — after application, alter a disposable copy of the current XML before restore. Confirm restoration fails closed and retains the backup/metadata for manual recovery.
16. **Discord Bot persistence** — with the Bot configured, press F2 while idle, start/stop recording, start/stop a strategy, and exercise one failure/recovery. A remote status command must still be processed after every ordinary cleanup.
17. **Scrollbar teardown** — release a drag normally, close the GUI while dragging, and exercise a child-window disappearance. Confirm dragging clears and no 10 ms callback remains active.
18. **Anti-downgrade** — rerun OpenCV native, TimeScale 2x/watchdog, Hotbar OFF, DJ/abilities, standard difficulty, updater smoke, and Discord Bot checks.
