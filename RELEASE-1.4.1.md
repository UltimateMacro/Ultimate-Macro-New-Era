# Ultimate Macro 1.4.1

The tested merged build is now available on GitHub, the website and the signed
updater. Display version: **1.4.1**. Internal updater build: **1.4.1.2**.

## What's new

- Combined the supplied modified **1.3.3.10 gameplay/replay engine** with the **1.4 interface**.
- Restored the original **1.3.3a recorder**, including tower actions, raw inputs, editable shortcuts, undo and F2 stop/save.
- Added optional dashboard pairing, activity/results, device health, strategy editing/library installs, stop-after-match and cooldown controls.
- Kept separate UltBot linking for Status, Start, Stop and requested foreground-Roblox screenshots, with local permissions.
- Added lightweight tray/background mode: close the window without disconnecting, reopen from the tray, or use explicit Exit to fully quit.

## Fixes and improvements

- Recording shortcuts now display readable names such as **Ctrl+F** instead of internal scan codes. Wider single-line fields prevent wrapping, and unchanged bindings keep their exact stored codes.
- Fixed conflicting shortcut aliases, protected F1/F2 and original recorder actions, and improved save/rebind validation.
- Improved dashboard pairing timeouts, connection errors, command retries, match-end reporting and cooldown recovery.
- Fixed repeated close/reopen, resize cleanup, stale UI callbacks and tray Exit leaving an old run marked for resume.
- Kept automatic chat closing enabled, corrected tool startup paths and limited watchdog cleanup to owned helpers.
- Signed updates use a protected replacement key, verify the exact ZIP and install only after approval into a separate folder.

## How to update

**Older builds using the lost signing key need one manual ZIP install.**
Extract the complete download into a new folder and open **Start Ultimate
Macro.cmd**. Existing new-key builds can use **Check / review update**. The old
installation and personal data are not deleted, and nothing restarts automatically.

GitHub, the website and updater distribute the same ZIP bytes:
`133be2c971cd85c052bf9ae309b9c114bc59ec053dae28eb51512e0a5ff5a126` (SHA-256).

## Testing and known limits

325 automated assertions passed across shortcut, recorder, dashboard-contract
and resident-lifecycle tests, plus hidden layout, health-worker and updater
checks. The actual signed updater download was verified. Defender found no
threats in this exact ZIP; that is not a universal antivirus guarantee.

Background game input/OCR tests were mocked, so this is not a claim that every
live strategy or gamemode is bug-free. The retained engine's 2x placement and
ability-cooldown behavior still needs strategy-specific testing; try 1.5x if
2x misses placements. Please report issues with the build and strategy name.
