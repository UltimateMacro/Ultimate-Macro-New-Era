# Ultimate Macro 1.4.1.3 — chat-close hotfix

* Restored the supplied modified 1.3.3.10 chat-button detection and click position (140px). The 1.4.1 build had changed it to 80px, which could leave chat covering the inventory.
* Added **Settings → Macro settings → Automatically close Roblox chat**, enabled by default when no preference is saved. The preference is saved across relaunches.
* Kept the original auto-equip, map-selection, replay, restart, timescale and ability routines. Dashboard activity reporting remains separate from their gameplay decisions.
* Kept the recorder, dashboard, UltBot linking, tray mode and signed updater from 1.4.1.

Extract the complete ZIP into a new folder, or use **Settings → Check / review update** in a build using the replacement signing key. Builds trusting the deleted old key still need one manual install; signature verification is not bypassed.

This is a targeted chat-close fix, not a claim that every strategy now works. Outdated community strategies, including strategies affected by game balance changes, still need updated strategy files. Background regression tests use inert input ports, not live matches.
