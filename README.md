# Ultimate Macro 1.4 — AutoHotkey edition

Ultimate Macro for Tower Defense Simulator, with the 1.4 Python/Qt window rebuilt
in **AutoHotkey v2**. Launch the macro with `Main.ahk`; it does not require
Python or a compiled macro EXE. A distribution ZIP can include a separate
optional updater binary. The macro also runs without that helper.

## Run it

1. Extract the whole folder (do not run it from inside the ZIP).
2. Double-click **`Main.ahk`** (needs AutoHotkey v2, 64-bit). Without AutoHotkey
   installed, run it with the bundled interpreter:
   `engine\submacros\AutoHotkey64.exe Main.ahk`
3. Accept the terms, pick a language, choose a strategy and press **Start**
   (F1 in Roblox). **F2** stops, **F8** is the emergency stop from anywhere.

Requirements are the same as the macro has always had: Windows 10/11, 100 %
display scaling, Roblox in windowed mode, TDS UI scale *Large*, camera shake off,
*Prefer Vertical Upgrades* on, and the English (US) Windows language pack for OCR.

## What is in the folder

| Path | What it is |
| --- | --- |
| `Main.ahk` | The app: window, settings, library, recorder and engine host. |
| `ui\` | Painted UI toolkit (GDI+), main window, dialogs. |
| `app\` | Settings store, strategy parser, engine host (WM_COPYDATA), Roblox/docking, Discord, input capture. |
| `engine\` | The 1.4 patched gameplay engine (`UM14Engine.ahk`) + images, native image search and the AutoHotkey interpreter. |
| `assets\` | Background, logo, startup sounds, translations, bundled strategies. |

Your settings, strategies and recordings live in
`%LOCALAPPDATA%\UltimateMacro14AHK`. On first start the app copies your profile,
strategies and recordings from the Python 1.4 app (`UltimateMacro14Python`) if it
finds one. Updates use the same AppData profile, so extracting a new app folder
does not replace your settings, strategies or recordings.

## Updates

The optional helper checks a dedicated AHK channel and downloads verified ZIPs
quietly when **Check and download on launch** is enabled. **Review update** shows
the signed SHA-256 and size and asks before installing. An accepted update is
extracted to a new folder under `%LOCALAPPDATA%\UltimateMacro14AHK\VerifiedUpdates`.
The helper never replaces, closes, or restarts the running copy. Use **Open update
folder**, close the old copy, and run the new `Main.ahk` when you’re ready. The
AHK update channel is separate from the existing 1.4 EXE updater.

In local test builds, the helper may report that the AHK channel is unavailable.
That does not prevent the macro from running. This ZIP can be extracted and run
manually without enabling update checks.

The macro sources and their notices are in this repository. The optional
updater is distributed separately as a binary; it is not required to build,
modify, or run the macro. See [1.3.3.10 comparison and release checks](COMPATIBILITY.md).

## How it fits together

`Main.ahk` is the launcher. When you press Start it writes a fresh, secret-free
`Settings.tds` and a validated copy of the strategy, starts
`engine\UM14Engine.ahk` with a one-time session id, and talks to it over
WM_COPYDATA with a fixed command allowlist — the same protocol the C# host used.
Stop asks the engine to stop and terminates it after 8 s; F8 terminates at once.
Only processes started from this folder's interpreter are ever closed.

Recording uses the engine's own recorder, driven from the Record page: Ctrl+1–5
picks the hotbar slot, your placement key places with an automatic tower ID,
and F2/F8/Stop keep a draft you can edit (remove towers) and then save.
"Record as you play" captures allowlisted game input in the launcher and is
replayed by the engine's input playback.

## Support

* Output → **Export log** saves the visible log.
* Script errors are written to `%LOCALAPPDATA%\UltimateMacro14AHK\error.log`.
* Create an empty `debug.flag` file in that folder to mirror Output into `debug.log`.

Original macro by Darksen — https://discord.gg/DQnc2JDJtr. Licensed GNU GPLv3
(see `LICENSE`, `licenses\` and `engine\ENGINE-NOTICE.md`).
