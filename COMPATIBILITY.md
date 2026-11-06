# 1.3.3.10 comparison

The supplied TDS-Modified-Macro reference identifies itself as 1.3.3.10 in
`Main.ahk`. This comparison is from the two source trees, not a live benchmark.

| Area | 1.3.3.10 modified macro | 1.4 AHK |
| --- | --- | --- |
| Auto-equip | Uses template matching, action-button colors and timed menu clicks. Its wide-window unequip sweep uses the column at 61% of the client width. | Retains the reference search, action templates, colors and 10/20 ms input defaults. Current whole labels, live-row geometry and bounded read retries handle newer inventory and docked layouts. A click must change its own button before continuing. Unknown slot order stops playback instead of silently selecting the wrong tower. |
| Modes and modifiers | Offers configurable mode-list scroll and votes once after selecting all modifiers. | Keeps the 1.4 mode navigation, separates Easy from Casual, and uses the reference one-click modifier vote sequence with docked coordinates. |
| Chat | Clicks a fixed topbar position after checking one white pixel. | Closes a recognized open Roblox chat panel before setup or camera alignment. Unrecognized or already-closed chat is left alone. |
| Settings | Uses legacy INI files and retains settings and statistics across its updater. | Uses an independent AppData profile. Failed Python-profile imports retry without overwriting files already copied. |
| Updates | Resolves GitLab tags or GitHub releases and offers to apply the downloaded archive. | Downloads a verified ZIP in the background. An explicit confirmation extracts it into a new folder; launch remains manual. |

Before a public release, test a real signed AHK update end to end from an older
AHK build, verify that the EXE channel stays unchanged, and replay loadout and
modifier setup with docking both enabled and disabled. Syntax checks and
offline signature fixtures do not cover those live behaviors. The exact-package
updater test uses a temporary signing key and does not contact the production
feed. It is separate from the signed live feed check. The 1.4 UI, ownership
guards and update consent are not byte-for-byte copies of the reference;
the original project and engine notices remain intact.
