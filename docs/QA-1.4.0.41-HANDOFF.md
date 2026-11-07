# 1.4.0.41 developer handoff — unfinished QA build

This is work in progress, not a release candidate approved for publication. The
user requested a PR so the developers can finish it. Keep the public website,
GitHub release and signed updater on 1.4.0.40 until the remaining work is verified
and a release is separately approved. Do not describe this build as bug-free.

## Where to continue first

The latest exact packaged build still stops during VIP map verification. Resolve
this before calling setup, strategy playback or repeat verified end to end.

Reproduction from the last live run on TDS 2.18.1:

1. Use a VIP account, Roblox maximized (1920 x 1009 client in this run), docking
   off, Auto Equip off, and the existing equipped towers. Open Roblox chat first.
2. Run an Easy / Solo strategy requesting Dead Ahead. The isolated smoke strategy
   used for QA would place one Elf Camp and wait, but never reached placement.
3. At 18:36:46 the macro verified chat closed; at 18:37:03 it selected Easy.
4. It entered the exact Dead Ahead query and pressed the verified filtered tile
   at 18:38:23. The picker closed, but the short green map-change receipt was not
   accepted. The fallback checked the active vote board at 18:38:30.
5. At 18:38:33 it stopped with:
   `Could not recognize the exact map name at the vote board; no vote or strategy placements were sent.`

The character was at the voting pad with the E Vote prompt visible. From the
near-vertical camera view, the board labels were almost edge-on and unreadable.
That is a suspected reason the fallback cannot prove the map, not a confirmed
root cause. Investigate the receipt capture timing and a readable, verified board
view. Preserve exact-map and purchase checks; do not vote merely because the
picker closed. The macro was idle after the failure. No automated vote or
placement followed, and testing was then stopped at the user's request.

Primary code: `engine/lib/UM14Features.ahk`, `engine/lib/UM14Toast.ahk`,
`engine/lib/UM14WindowOCR.ahk`, and the setup sequence in `engine/UM14Engine.ahk`.

## Changes included

| Area | Implementation / intent |
| --- | --- |
| Lobby and modes | Handle the current Update Log and Login Rewards, wait for dismiss animations, distinguish Easy from Casual by labels, keep Hardcore on its own card, and report locked Voidcore. |
| VIP map selection | Recognize the current Override Map caption, enter literal search text, independently revalidate the query/tile, isolate the green receipt, and require exact-map verification before voting. This remains the live blocker above. |
| Chat | Restore the reference chat hit point with open/closed icon checks. Settings > Gameplay > Auto close Roblox chat defaults on, persists the preference, and leaves closed chat alone. No chat contents are read or logged. |
| Ready and replay | Keep the pointer off captions while checking the verified green press point. Only the exact match-restart control is eligible, not a paid Restart Wave button. |
| Placement | Avoid cancelling an already-open tower panel. If placement succeeds without a panel, require the increased unit count plus the owned tower tooltip before one reselection. |
| Strategies | Ignore commented commands, preserve distinct upgrade paths/batching semantics, reject unsupported commands before Start, and add launcher-to-engine option coverage. |
| Settings and UI | Fix stale docking status, clarify recording opt-in/alignment/shortcut guidance, and bring the verified updater review window forward. |
| Dashboard | Add opt-in Settings pairing, current-user DPAPI storage, heartbeat, offline/revoked states, and explicit Disconnect. Details below. |
| Runtime | Replace both interpreter copies with the same unmodified official AutoHotkey 2.0.31 bytes; retain upstream notices. |

Other useful entry points: `app/Store.ahk`, `app/Engine.ahk`, `app/Strategy.ahk`,
`app/Dashboard.ahk`, `app/Updater.ahk`, `ui/Window.ahk`, and `Main.ahk`.
`CHANGES.md` describes implemented changes; it is not evidence that every feature
has passed live testing.

## Dashboard contract and remaining integration check

- Release origin is `https://ultmacro.xyz`; routes are under `/api/dashboard/v1/`.
- Claim sends `POST pairing/claim` with the normalized `XXXX-XXXX` code (hyphen
  retained), device name and app version. The one-time code is not persisted or
  logged. Invalid, expired/used, and rate-limited responses have distinct messages.
- A successful claim saves the token with current-user Windows DPAPI, sends an
  immediate heartbeat, then repeats asynchronously every 20 seconds. Temporary
  failures retain the token and show offline; 401 clears it and requires pairing.
- Explicit Disconnect sends `POST device/disconnect` with `{}`. Normal exit stops
  timers but retains the encrypted token for restoration on next launch.
- Requests have bounded timeouts and do not follow redirects or silently fall
  back to HTTP. Responses cannot start, pause or otherwise control macro runs.
- An optional ignored, deliberately unshipped
  `app/DashboardDevelopment.local.ahk` include is the development override; the
  allowed local HTTP origin is exactly `http://127.0.0.1:4174`. See
  `Dashboard.ResolveOrigin` and `DashboardDevelopmentOrigin` in `Main.ahk`.
- Real WinHTTP loopback checks passed claim, heartbeats, offline recovery,
  revocation, relaunch, disconnect, expiration and redirect refusal. The r14
  packaged build measured the second heartbeat at 20,006 ms; Dashboard code is
  unchanged in r17. **A real production website pairing code has not been claimed
  in an end-to-end test.** Verify that integration separately before advertising
  production dashboard connectivity.

## Recorded verification

Latest gameplay/code checkpoint: `3137a1c53a7f68439f863044d4361aba9bcf6f7a`.
The subsequent handoff-document commit does not change executable code.

Local unpublished package: `Ultimate-Macro-1.4.0.41-AHK-QA-r17.zip`.
SHA-256: `A1FD96EB87D39A23197A64386DBA788564502DDE5B56189B55260589355D84CC`.
This hash identifies the previously tested local ZIP, not a GitHub-generated
branch archive. The ZIP and private test profiles/logs are not included in this PR.

Recorded checks against the exact extracted package:

- Eleven AHK suites passed: `TestDashboard`, `TestInventoryQuery`,
  `TestLegacyProfile`, `TestModeSelection`, `TestPrivateServer`, `TestReleaseUi`,
  `TestStrategyMatrix`, `TestTimescale`, `TestToastMask`, `TestUiRendering`, and
  `TestWorldGeometry`.
- Six syntax checks passed: `Main.ahk`, `engine/UM14Engine.ahk`, and
  `engine/submacros/{um14_guard,auto_open_consumable,auto_coa,auto_spin}.ahk`.
- The engine manifest verified 173 file hashes. The strategy matrix parsed seven
  bundled strategies / 1,107 steps / 350 option/profile handoffs. These are
  offline checks, **not 350 matches or seven completed live strategies**.
- Both existing updater helper self-tests, including the exact package test,
  passed using an isolated test signature. No release signing key or public
  updater feed was used. The closed-source helper itself is unchanged.
- Defender scanned the exact ZIP and found no threats. There was no VirusTotal
  upload or verification; absence of future antivirus false positives is not
  guaranteed. Both official 2.0.31 interpreter copies have SHA-256
  `5073EE85DA091653C7C6CE32CACDA3A0B4BFB51649823C10015BA0BD71ACB73C`.

Live evidence is narrower: open chat closed before Easy selection in multiple
maximized runs; already-closed chat stayed closed; the Settings toggle saved both
states in an isolated profile. Earlier checkpoints entered Dead Ahead and reached
Ready, but not as one completed final-build run. Placement without an open panel
was reproduced manually and then regression-tested. Dock/undock sizing was
observed earlier. No saved loadout was overwritten and no purchase or timescale
ticket was consumed.

## How to repeat source checks

From the repository root on Windows, use the bundled interpreter with
`/ErrorStdOut /validate <script>` for each syntax target above and
`/ErrorStdOut <TestName>.ahk` for each suite. Run hidden, wait for the process,
capture stdout/stderr, require exit code 0, and apply a bounded timeout (the
existing CI workflow demonstrates this). The current workflow does not include
every additional local QA suite; run all eleven explicitly when continuing.
Use a throwaway test profile, not the user's existing installation, for any
subsequent live/manual tests. Do not run the six syntax targets as ordinary
scripts simply to validate them.

Also run:

```powershell
python .github/scripts/verify_engine_manifest.py
python .github/scripts/validate_locales.py
```

Any engine-file edit requires updating its byte-exact SHA-256 entry in
`engine/engine-manifest.json`. Do not include local profiles, pairing tokens,
Discord report exports, signing material or the development override in a ZIP.

## Remaining release gates

- Resolve and retest the latest exact-map verification failure above.
- Verify final-build setup -> map -> Ready -> placements -> results -> repeat,
  with docking off/on and compact/maximized layouts. Maximize is not exclusive
  fullscreen; the final build has not completed a fullscreen strategy matrix.
- Exercise the required modes, modifiers, Auto Equip, placement/reselection,
  abilities, timescale, recording and settings in real play. Voidcore was locked
  on the test account, so it has no live pass.
- Perform real website claim -> heartbeat -> disconnect/relaunch integration.
- Rebuild from the reviewed commit and rerun package integrity, updater approval,
  decline, extraction and no-overwrite checks before requesting release approval.
  Quiet download must still require user approval to install; never auto-restart.

The 1.3.3.10 reference shares the broad loadout -> mode/squad -> map -> Ready ->
replay flow and mouse/key timing defaults, but these implementations are not
identical. For example, the reference defaults Restart off while the 1.4 launcher
sets it on. Do not infer full compatibility or bug-free gameplay from that
comparison alone.
