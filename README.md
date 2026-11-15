# Ultimate Macro 1.4.1.5

Strategy cycling is back: **Run → Strategy cycling → Strategy rotation**.
Choose a second strategy and swap after a chosen number of **Runs** or
**Minutes**. The original 1.3.3a two-slot rotation alternates between matches
and enables auto-equip. It is off by default. The supplied modified 1.3.3.10
had removed cycling; its remaining gameplay core is preserved.
See [the cycling changelog](CHANGELOG-1.4.1.5.md).

The 5–20 value under Run options is **map-list scroll steps**, not a match
limit. There is no fixed 20-match cap. The interface now explains the field;
the existing gameplay and replay logic are unchanged. See
[the clarification changelog](CHANGELOG-1.4.1.4.md).

Chat-close hotfix: **Automatically close Roblox chat** is visible in Settings
and on by default. Chat detection/clicks use the supplied 1.3.3.10 position.
See [the hotfix changelog](CHANGELOG-1.4.1.3.md).

The supplied modified **1.3.3.10 gameplay engine** with the Ultimate Macro
1.4 interface, optional UltBot/dashboard connections, and verified ZIP updates.

Extract the entire ZIP to a new folder, then open **Start Ultimate Macro.cmd**.
This uses the included official 64-bit AutoHotkey runtime without changing
your installed AutoHotkey. Don't run the macro from inside the ZIP.

## Background mode and tray

Closing the main window now keeps Ultimate Macro running in the system tray;
it does not stop a run or disconnect dashboard/UltBot. Use **Open Ultimate
Macro** (or double-click its tray icon) to reopen it. Use **Exit Ultimate
Macro** to fully quit. The painted UI and its timers/buffers are released
while closed; original settings, recording controls and selected strategy
survive reopening. An explicit exit clears legacy run-resume state.

An authenticated remote Start acknowledges the informational required-towers
prompt after three seconds. Local starts keep the original 60-second timeout;
first-run setup and all normal run/recording guards are unchanged. Remote
Start still requires the existing permissions. Pairing now allows longer
network timeouts and explains unreachable/HTTP-error responses more clearly.

Stop other TDS macros before starting this one. Starting a strategy can
relaunch Roblox, and its hotkeys control the game. This is not a Roblox exploit;
the macro uses local mouse/keyboard automation and the original recognition
libraries. Read the original setup instructions and configure TDS first.

## Retained engine and tools

Strategy playback, auto-equip, game navigation, timescale handling, abilities,
modifiers, playtime rewards, webhooks and timing defaults retain the
supplied 1.3.3.10 routines. The original spin and consumable tools remain in
Tools, with a corrected startup folder. Original defaults and the shared
`%APPDATA%\Ultimate_Macro` settings/resume paths remain in use.

The lifecycle, update, and presentation adapters are intentional exceptions:
the watchdog is now stopped by its owned process handle; unrelated scripts
are not closed by name; and the old upstream overwrite updater is retired.
Automatic chat closing remains on at the original equip/map/camera checkpoints;
its two horizontal positions have the specifically requested 140→80 hotfix,
and it acts only while Roblox is in the foreground.
See RELEASE-NOTES.md for the exact scope and outstanding testing.

## Record

The modified 1.3.3.10 distribution has no working recorder. With the owner's
approval, this build restores the original **1.3.3a recorder** in a separate
Record tab while keeping 1.3.3.10 replay. Choose map, mode, towers/modifiers and
options, then Start recording after joining your match. F places a tower with
the original slot/ID prompts; upgrade clicks and original action shortcuts are
retained. Ctrl+Shift+E toggles raw inputs; Ctrl+Z undoes; F2 stops and offers to
save. Saved `.strat` files are selected for replay automatically.

Recording shortcuts are editable on the Record page. Inputs from other apps
are discarded. Saving is atomic, and selling preserves preceding spawn/upgrade
steps instead of deleting history required by replay. Recordings are stored in
`%APPDATA%\Ultimate_Macro\Recordings`. The original recorder recommends 1080p;
its warning and strategy format are preserved. Live TDS testing is still needed.

The shortcut boxes show readable names such as Ctrl+F rather than internal
scan codes. Type a combination such as Ctrl+P, then press Enter or leave the
box to save. Unchanged imported bindings retain their exact stored codes.
Empty, invalid, reserved and conflicting edits revert to the previous binding.

## Discord → ULT Bot remote control

1. In the Ultimate Macro Discord, run `/remote link` or `/remote setup`.
2. Paste the private ULT1 code in the app's Discord tab and accept the local
   status/stop consent checkbox. Don't post your code in a channel.
3. Try `/remote status` first. `/remote devices` shows the linked PC.
4. Remote Start and requested Roblox screenshots each require their own
   additional local opt-in. Complete first-run prompts and choose a strategy
   locally before using `/remote start`.
5. `/remote stop` uses the original stop/reload handler, then reconnects.
6. Use Disconnect or `/remote unlink` to revoke the connection.

Requested screenshots require a single foreground RobloxPlayerBeta game
window. Other games, desktop pixels, and background windows are not captured.
If Roblox cannot provide a valid image, the request returns an error instead
of falling back to a desktop screenshot.

UltBot's account, role and prerelease checks remain server-side. This version
may require tester access until the public release is registered.

## Settings → Connect to Dashboard

Enter the website's XXXX-XXXX pairing code. A successful heartbeat makes the
desktop appear connected; temporary failures show Offline and retry. The
paired dashboard can show run activity, verified results/rewards and current
CPU/GPU/RAM/process health. Authenticated website actions support Start, Stop,
Stop after match, cooldowns, strategy selection/editing/library installs, and
closing an explicitly selected current app. It is independent of UltBot.

Temperature cooldowns require live CPU sensors from LibreHardwareMonitor
(local data.json on port 8085, or compatible monitor WMI). Missing/stale sensors
are not treated as a cool CPU. Pause/resume and a second strategy slot are not
supported by the retained single-strategy runtime and return a clear error.
Disconnect revokes the link and clears queued dashboard telemetry/cooldowns;
ordinary app exit retains the encrypted link for relaunch.

Both links are optional, HTTPS-only in release builds, and off until paired.
Windows DPAPI encrypts saved credentials for your Windows user. One-time codes
are cleared after submission and are not saved to settings or logs.

## Verified updates

Quiet downloads are optional and off by default. When enabled, the app checks
at launch and every 30 minutes. Check / review update also works manually.
The helper checks the signed manifest, expiry, ZIP size and SHA-256, and safe
archive paths. Installation always requires approval.

Every approved update creates a clean version folder in
`%LOCALAPPDATA%\UltimateMacro14AHK\VerifiedUpdatesV2`. New files are included,
replacements contain the new bytes, and files omitted from the new release
aren't carried into that folder. The old installation and user data stay
untouched for rollback. Nothing is killed, launched, or restarted by updating.

Keep custom strategies in a separate folder or retain the previous version
folder; the selected strategy setting can continue to reference that file.
Updates do not delete arbitrary personal files or silently merge installations.

The old private signing key was lost. This build uses a new protected signing
identity on a separate v2 channel. Older versions need one manual install to
trust it; no signature bypass or automatic trust replacement exists. See
`updater/UPDATE-TRUST-V2.md`. Updates use only the separate v2 signed feed;
the old feeds are not repinned or redirected around signature verification.

## Timing and compatibility

If 2x misses placements, try 1.5x. Raise mouse/key delays gradually if clicks
are missed. These engine behaviors have not been rewritten in this release.
Read SECURITY.md before claiming that any antivirus warning is harmless.

## Credits and source

Ultimate Macro by **Darksen**; modified 1.3.3.10 by **IlMlN**; 1.4 interface
and contributors retain their original credits. The supplied legacy README
is preserved unchanged in docs/LEGACY-README.md. Presentation/source licensing
and the official AutoHotkey license are included. No personal credentials or
release signing keys belong in this ZIP.
