# Dashboard verification — 1.4.1

This records isolated verification of Aiden's supplied Ultimate-Macro-1.4.1.zip,
the merged 1.4.1.1 additions and the recording-shortcut hotfix.
Display version remains 1.4.1; the shortcut hotfix uses updater build 1.4.1.2.

## Fixed

1. Stop after match now reaches the existing watchdog and clears the legacy
   Running flag before restarting. Match-ending cooldowns use the same handoff.
2. Verified watchdog results now produce atomic, bounded, duplicate-safe disk
   receipts. Available OCR coins, gems, tower XP and duration feed the dashboard
   activity/earnings API even when Discord webhooks are disabled. If Roblox is
   not foreground, only the verified result and saved map are reported; it does
   not steal focus to collect reward readings.
3. PACKAGE-MANIFEST.json is regenerated from every shipped file, not reused
   from the original archive.

Additional integration fixes cover the reserved-variable startup error,
32-character activity IDs, selected-slot strategy editing, async poll progress,
result-ack retries, safe-stop cancellation, stale health/process identities,
temperature/timed cooldowns, and credential revocation cleanup. Settings and
the privacy documentation describe the new dashboard permissions.

## Checks completed

* Both Main.ahk and watchdog.ahk pass AutoHotkey 2.0.31 load validation.
* 100 protocol/runtime assertions passed with synthetic accounts and loopback
  WinHTTP. The pinned website backend's real local-store pairing, snapshot,
  command, result, activity and earnings implementations were used; external
  database/security/push dependencies were isolated. No production database,
  real account, purchase or public deployment was used.
* Tested website backend commit: 971f7582e5d0c8e0028839a0bc07864474779737.
  Its previously retrieved, hash-verified source was reused locally; these
  tests did not contact the public website or its production database.
* Claim errors, DPAPI persistence, heartbeats/offline recovery, strategy
  read/edit/conflicts/install/select, start/stop acknowledgements, safe stop,
  result/reward retry/deduplication, cooldowns, process-close identity checks,
  restart, revocation and explicit disconnect passed.
* The actual hidden PowerShell health worker produced a valid bounded sample.
* Complete hidden UI opened all 7 tabs at 4 sizes; dashboard code masking,
  clearing and connection states passed. No Windows capture was used.
* 82 hidden resident-lifecycle assertions passed: eight close/reopen cycles,
  preserved original form/modifier values, no duplicated bindings, released
  graphics/timers, surviving connection-timer ownership, pending-hide
  cancellation, remote-prompt reset and explicit exit/resume cleanup.
* Archive contents, per-file sizes/hashes and unchanged bundled binaries are
  checked again when the ZIP is built.

## Still requires live testing

Game actions and OCR values were stubbed in the protocol tests. They do not
certify every TDS strategy, actual reward recognition, or a real logged-in
website/browser session. Pause/resume and strategy slot 2 remain unsupported.
CPU-temperature cooldowns require an available compatible hardware monitor.
The retained replay/gameplay and native recognition DLLs were not rewritten.
The recorder was separately restored from 1.3.3a with owner approval and 42
round-trip assertions; the updater was rebuilt for the separate v2 trust channel.
No claim of zero bugs or universal antivirus clearance is made.
