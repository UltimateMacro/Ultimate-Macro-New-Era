# Ultimate Macro 1.4.1

## Recording shortcut hotfix — build 1.4.1.2

* Fixed raw scan codes in the Record tab: bindings now display readable names such as Ctrl+F and Ctrl+Shift+E.
* Fixed shortcut-field wrapping/clipping with wider, explicitly single-line fields.
* Added readable shortcut editing while preserving exact saved scan-code bindings when unchanged.
* Fixed duplicate checks across scan-code/key-name aliases and protected F1/F2, undo and the original fixed recorder actions.
* Retained the merged tray/background mode, recorder, dashboard fixes, gameplay engine and protected updater.

101 shortcut regression checks passed, alongside 100 dashboard, 82 resident
lifecycle and 42 recorder round-trip checks. Hidden UI/input tests do not
certify every live TDS strategy.

This hotfix is packaged for the signed v2 updater. Older builds using the lost
signing key require one manual ZIP install; signature checks are not bypassed.
Website and GitHub releases are outside this hotfix's publication scope.

## Retained 1.4.1 changes

* Merged the supplied 1.4.1.1 additions with the latest recorder/dashboard/updater fixes; public display version stays 1.4.1 (internal build 1.4.1.1).
* Added lightweight tray/background mode with Open and explicit Exit. Closing the window keeps existing links available.
* Fixed tray reopening, repeated close/resize cleanup, stale callbacks and duplicated controls; preserved selected strategy and recording settings.
* Fixed explicit tray Exit leaving an old run marked for automatic resume.
* Increased dashboard pairing timeouts and improved connection/error messages.
* Remote Start acknowledges the required-towers notice after three seconds. Local prompts, first-run setup and permissions remain unchanged.
* Restored the Record tab using the original 1.3.3a recorder, alongside the modified 1.3.3.10 gameplay/replay engine.
* Restored tower placement, upgrade clicks, targeting, DJ tracks, cloning, raw inputs, undo, recording shortcuts and F2 stop/save.
* Fixed recorded sell ordering, safer strategy saving, and recording accidentally capturing input from other apps.
* Improved UI responsiveness and resizing, and fixed small-window layout errors.
* Added dashboard pairing, activity/results, device health, strategy editing/library installs, safe stop-after-match and cooldown controls.
* Fixed dashboard startup, activity IDs, command retries, selected-strategy editing and match-end reporting.
* Added optional UltBot linking for Status, Start, Stop and requested Roblox screenshots, with separate permissions for Start and screenshots.
* Kept automatic Roblox chat closing enabled and fixed tool startup and helper/watchdog cleanup.
* Rebuilt the signed updater with a new protected signing identity and a separate update channel. The encrypted signing-key backup was recovery-tested.

**Updating:** Older versions need one manual install to trust the replacement
signing key. Future signed installations still need your approval and keep the
previous copy intact. This hotfix uses only the separately signed v2 feed.

**Testing:** Recording/gameplay inputs and OCR were mocked in
background tests; live TDS testing is still needed. No zero-bug or universal
antivirus-clearance guarantee is made.
