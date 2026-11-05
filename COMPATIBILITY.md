# 1.3.3.10 comparison

The supplied TDS-Modified-Macro reference identifies itself as 1.3.3.10 in
`Main.ahk`. This comparison is from the two source trees, not a live benchmark.

| Area | 1.3.3.10 modified macro | 1.4 AHK |
| --- | --- | --- |
| Auto-equip | Uses template matching, action-button colors and timed menu clicks. Its wide-window unequip sweep uses the column at 61% of the client width. | Uses the same search, action templates, colors and wide-window sweep. Docking needs a separate card-strip sweep. A click must change its own button before continuing. If a required tower stayed equipped and its slot is unknown, the macro stops with instructions rather than replaying with the wrong tower order. |
| Modes and modifiers | Offers configurable mode-list scroll and votes once after selecting all modifiers. | Keeps the 1.4 mode navigation and uses the reference one-click vote sequence, with separate docked coordinates. Live checks are still required. |
| Settings | Uses legacy INI files and retains settings and statistics across its updater. | Uses an independent AppData profile. Failed Python-profile imports retry without overwriting files already copied. |
| Updates | Resolves GitLab tags or GitHub releases and offers to apply the downloaded archive. | Downloads a verified ZIP in the background. An explicit confirmation extracts it into a new folder; launch remains manual. |

Before a public release, test a real signed AHK update end to end from an older
AHK build, verify that the EXE channel stays unchanged, and replay loadout and
modifier setup with docking both enabled and disabled. Syntax checks and
offline signature fixtures do not cover those live behaviors. The exact-package
updater test uses a temporary signing key and does not contact the production
feed. Modifier setup still requires a live pass to check that TDS accepts the
selection and the final vote.
