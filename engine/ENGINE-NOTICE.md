# Ultimate Macro 1.4 engine mode — modification notice

This folder is a **modified version** of *Ultimate Macro (macro for TDS)* 1.3.3a by
**Darksen** (https://github.com/DarksenDev/tds-macro), licensed under the
**GNU General Public License v3** (see `LICENSE`, unchanged). Original credit is retained
in every original file. Modified by the Ultimate Macro 1.4 project, October 2026.

Generated from the untouched 1.3.3a archive (SHA256
B7F33161C05B4B7A123F339F9C458BE1D7C82F1D33C27182B589E62EF6FD317A) by `EnginePatcher`;
`engine-manifest.json` lists every applied patch with its reason and every file's hash.
Original gameplay paths are retained, with the exact fixes and compatibility
ports listed in that manifest. This is not a claim that gameplay is unchanged
or that every fan-fork feature has been imported or verified in Roblox.

## What changed

- `Main.ahk` → `UM14Engine.ahk`; `submacros/watchdog.ahk` → `submacros/um14_guard.ahk`.
  New names so 1.3.x's process matching ("Main.ahk", "watchdog.ahk") and ours never
  close each other's processes.
- Runs only when started by the 1.4 launcher with a current session; data lives in the
  launcher's isolated folder instead of `%APPDATA%\Ultimate_Macro`.
- Legacy window hidden; the launcher is the interface. Narrow WM_COPYDATA bridge
  (`lib/UM14*.ahk`) with a fixed command allowlist.
- Upstream updater (`updater.ahk`, `update.bat`) not included.
- Recovery relaunch keeps the session (Reload() dropped its arguments).
- Guard closes only this session's engine (no unconditional PID close, no "Main.ahk" match).
- Security: strategy `Send("…")` steps accept exactly one key name.
- Privacy: Discord/webhook screenshots capture only the Roblox window.
- Blocking dialogs that the launcher now shows (required towers, resolution warning,
  first-run checklist) are skipped; the multi-client conflict is reported to the launcher.
- Fixed-data passive input replay supports key/button edges, camera dragging and
  wheel steps; malformed or unbalanced sequences are refused by the host.
- Audited modified-fork ports cover mode-list scrolling, literal search text,
  exact modifier aliases and missing-tower guards. The original Party and
  recording paths were not deleted to match the stripped-down fork.
- Small/windowed clients retain original-size UI template coverage as well as
  scaled templates. Lobby detection refreshes client geometry; selection-stage
  deadlines cannot reset themselves. Unrecognized lobby/map-vote controls stop
  the run with an error instead of closing Roblox and automatically looping.
- Game searches replace old text with paced literal characters and recheck
  foreground ownership; the launcher reapplies original Event mouse settings.
  Modifier setup waits for its actual search control with a bounded deadline.
  DJ operations use shared ability flags, require a recognized track control
  and have a fixed retry deadline. Placement clears a prior tower panel first
  so that an old DJ menu cannot confirm a new tower. These code-level fixes
  still require gameplay confirmation, including the bundled Yeti route.

## Your rights

You may copy, modify and redistribute this engine under GPLv3. The corresponding
source is this folder plus the patch generator in the 1.4 source distribution.


## AutoHotkey edition (launcher written in AutoHotkey)

The Python/Qt UI and the C# LegacyHost were replaced by `Main.ahk`. The engine
above is unchanged except for these recorder patches (build `1.3.3a-um14.26-ahk1`):

- A01-recorder-state
- A02-build-id
- A03-verbs
- A04-verb-validation
- A05-record-flags
- A06-dispatch
- A07-apply-flags
- A08-f2-keeps-draft
- A09-f2-add-inputs
- A10-passive-hotkeys-off
- A11-click-upgrade-optin
- A12-sell-click
- A13-placement-slot
- A14-inventory-overlap-message

- A13 placement uses the launcher's Ctrl+1-5 slot and an automatic tower ID
  instead of two blocking InputBoxes (the dialogs remain as a fallback).
- F2 in Roblox while recording keeps a draft for the launcher instead of
  opening the legacy save dialogs.
- "Record as you play" disables engine recording shortcuts; the launcher
  captures allowlisted game input and the engine replays it (UM14Replay.ahk).
- "Record upgrade clicks" / "Record sell clicks" toggle the legacy click
  detection; sell clicks require a positive Sell-button image match.

Native files copied verbatim from the 1.3.3a release: `lib/ImageSearch/*.dll`,
`submacros/AutoHotkey64.exe` (AutoHotkey v2.0.12) and its byte-identical copy
`submacros/UM14Tools64.exe` used only for the crate utility.

## AHK gameplay compatibility pass (build `1.3.3a-um14.26-ahk2`)

- A15: inventory input follows the timed first-result and template/color flow
  of IlMlN's [TDS-Modified-Macro 1.3.3.10](https://gitlab.com/IlMlN/tds-modified-macro).
  The UI still pins the selected Roblox client for each action.
- A16: match setup keeps the reference's one-click modifier vote after all
  selections, using a separate point for the narrow docked layout.
- A17: recognizes exact short modifier names used by 1.3.3.10 and the legacy
  spelling `Commited`.

## AHK 1.4.0.40 (build `1.3.3a-um14.26-ahk3`)

- A19: guard waits for a real match, scopes disconnect recognition to the
  selected game, and stops if Roblox closes instead of relaunching the engine.
- A20: wait for the lobby on initial setup; allow automatic game replacement
  only for a confirmed disconnect or a verified result when rejoining.
- A21: hold and verify high-impact clicks, wait for the previous tower panel
  to close, and add bounded UI wait and pre-join tuning.
