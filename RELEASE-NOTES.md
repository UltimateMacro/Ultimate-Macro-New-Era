# Ultimate Macro 1.4.1.4

## Run-options clarification — build 1.4.1.4

* The reported 20 is the original map-list wheel-scroll setting, not a match
  count. Renamed the field to **Map-list scroll steps** and added an explicit
  explanation that it does not limit matches.
* Added a visible reminder that there is no fixed match-count limit and that
  F2 or dashboard stop controls stop a run. Explicit stop/cooldown behavior stays.
* Kept the gameplay engine, watchdog, recorder and dashboard modules unchanged
  from 1.4.1.3. No scroll limit was raised and no repeat logic was rewritten.
* Added an inert regression through more than 20 match-end/relaunch decisions
  and retained the hidden-layout, recorder, shortcut and updater tests.
* Fixed the release checker to compare the manifest with the actual launcher
  versions instead of rejecting every version after 1.4.1.2. Mismatches and
  changed file hashes still fail the check.

## Chat-close hotfix — build 1.4.1.3

* Restored the exact chat-button detection/click body from the owner's supplied
  modified 1.3.3.10 (140px, not the changed 80px). The foreground-app guard stays.
* Added a visible, persistent, default-on automatic chat-close setting.
* Pinned regression checks verify 12 original gameplay functions; dashboard
  notifications are the only additions in the three instrumented routines.
* Background tests exercise open/closed chat, disabled behavior, refusal to
  click other apps, setting persistence and hidden seven-tab layouts. They do
  not prove every live strategy works or repair outdated community strategies.
* Recorder, dashboard, UltBot, tray and signed-update behavior is retained.

The earlier release notes below are historical, not current publication status.

## Recording shortcut hotfix — signed updater build 1.4.1.2

* Replaced visible internal shortcut strings with readable modifier/key names.
* The existing shortcut fields are explicitly single-line and wider. Readable
  edits (Ctrl+P, Ctrl+Shift+E, etc.) save through the original hotkey/settings
  path; unchanged physical scan-code bindings are not silently rewritten.
* Added equivalent scan/VK/key-name conflict checks and reserved-action guards.
* Passed 101 hidden shortcut regression assertions covering the exact reported
  values, persistence, rejected edits, Enter commits, four sizes and reopening.
* Retained the previous merged engine, recorder, dashboard, tray and updater.
  Publication requested for the v2 updater only, not the website or GitHub.

## Merged candidate — 2026-11-14 (not published)

* Combined the supplied 1.4.1.1 tray/pairing/remote-start additions with the
  owner's latest recorder, dashboard fixes and replacement updater identity.
* Close keeps the app resident for existing dashboard/UltBot commands. Open
  and Exit are explicit tray actions. Reopening now resets destroyed UI state,
  prevents duplicate handlers/controls and preserves recording form values.
* Releasing a view cancels its rendering/tooltip work and ignores stale
  animation/layout callbacks. Closing no longer leaves a hidden 10ms hover poll.
* Explicit tray Exit clears the original resume flag instead of restarting a
  strategy on the next launch. Ordinary credentials remain encrypted/saved.
* Pairing uses a 35-second overall / 15-second receive timeout, clearer errors
  and bounded retry scheduling. Heartbeat cadence remains 20 seconds normally.
* Authenticated remote starts use a three-second required-towers notice; local
  starts retain 60 seconds. The temporary flag clears on busy/error paths.
* The Record tab and new pinned updater were retained rather than reverted to
  the older copies in the supplied archive. Display version remains 1.4.1;
  internal signed-update build increases to 1.4.1.1.
* Passed 82 resident lifecycle assertions (eight close/reopen cycles, four
  sizes and seven tabs), 100 loopback dashboard assertions, 42 mocked recorder
  round-trip assertions, complete hidden UI checks and the real health worker.
  No real game controls, screen capture or production account were used.

## Recorder and update-key recovery (local build, not published)

* Restored the original 1.3.3a Record page/handlers with the owner's approval.
  The modified 1.3.3.10 has no working recorder; replay remains 1.3.3.10.
* Restored original tower actions, upgrade-click capture, raw inputs, shortcut
  persistence and F2 stop/save. Added foreground-only capture, atomic save and
  corrected sell history needed for a valid saved-strategy replay.
* Passed 42 recorder round-trip assertions and all 7 hidden UI tabs at 4 sizes;
  game input/OCR was mocked. The 95 dashboard checks and health worker passed.
* Rebuilt the updater with a new pinned protected key and separate v2 channel.
  Existing clients need one manual install. An encrypted off-PC signing-key
  backup was downloaded and recovery/signature-tested on the owner's account.
* No GitHub, website or live updater publication was performed.

## Dashboard fix candidate (not published)

* Connected Stop after match and cooldowns to the existing watchdog restart.
* Added durable, duplicate-safe match-result receipts, including available
  coins/gems/tower-XP/duration readings, independent of Discord webhooks.
* Fixed dashboard health startup, valid activity IDs, selected-slot editing,
  asynchronous command progress, acknowledgement retries and revocation cleanup.
* Guarded CPU cooldowns against stale readings and cooler individual cores;
  kept process closing restricted to a fresh, matching selected app identity.
* Updated Settings consent text and regenerated every package-manifest hash.

The new dashboard paths were exercised against an isolated copy of the current
website backend using synthetic accounts and loopback HTTP. The real hidden
health worker and hidden Settings/page layouts were also checked. Gameplay
input/OCR in the protocol tests was stubbed: live TDS results, real account
pairing and public deployment are not certified by these background tests.

## Existing 1.4.1 changes

* Retained the supplied modified 1.3.3.10 gameplay routines in the 1.4 interface.
* Added persistent, opt-in UltBot linking for Status, Start, Stop and requested
  Roblox-only screenshots; Start and screenshots have separate permissions.
* Restored independent dashboard pairing with encrypted credentials, automatic
  heartbeats, offline recovery and explicit disconnect.
* Replaced the upstream in-place updater with pinned, signed ZIP updates.
  Clean version folders support additions, replacements, removals and renames
  without deleting the previous copy or personal data.
* Coalesced resize events and reused background frames while dragging; fixed
  the small-window Output layout error and checked repeated resize cleanup.
* Fixed spin/consumable tool startup folders.
* Kept automatic chat closing enabled at the original checkpoints and applied
  the requested horizontal icon/click coordinate fix from 140 to 80. It skips
  when Roblox is missing or not foreground.
* Removed filename-wide AutoHotkey cleanup and the taskkill process-tree call.
  The watchdog closes only its owned helper or verified parent handle.
* Updated the bundled interpreter to the official AutoHotkey 2.0.31 archive,
  verified against its upstream SHA-256. Kept the original image-recognition
  DLLs unchanged.

## Test scope / publication gate

Automated checks exercise hidden UI layouts, original callback wiring,
isolated tool timers, scoped lifecycle ownership, local HTTP protocol flows,
encrypted screenshot IPC, updater rejection paths, and clean-version file
transitions. Gameplay input is mocked in these background tests.

Live TDS strategy/mode runs, a real UltBot/dashboard account pair, and a real
Roblox screenshot still require validation. The known 2x placement and ability
cooldown behavior is unchanged. Do not call this zero-bug, universally
antivirus-clean, or tested successfully by every beta participant.

Display version: **1.4.1**. Signed-feed compatibility identity: **1.4.1.2**.
The ZIP by itself does not publish a release or change the website/updater.
