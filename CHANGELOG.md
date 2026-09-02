# Changelog

## Unreleased — reported runtime QA hotfix

### Fixed

- Multi-scale portable image detection when optional OpenCV binaries are absent.
- Frost and standard difficulty selection with bounded scroll + OCR fallback.
- The resettable Easy/difficulty timeout that could still hang indefinitely.
- Cross-resolution replay for raw clicks, cloning and Brawler repositioning.
- Juggernaut/path-tower branch-level recording semantics and path-aware upgrade batching.
- DJ track/color changes silently exiting after a single missed image.
- Auto Equip search-bar geometry and map verification settling/retry behavior.
- Generic green Ready clicks that could target unrelated UI.
- Watchdog phase semantics for long healthy matches after strategy steps finish.
- Automatic community-strategy refresh changing files inside Git checkouts and
  linked worktrees. Extracted official releases continue to refresh normally.
- Hotbar mouse selection using coordinates cached before Roblox client geometry
  was available. Hotbar OFF recording and replay now share placement-time,
  client-scaled numeric clicks with structured diagnostics; Hotbar ON is
  unchanged.

### Packaging

- Added the reviewed required runtime files
  `lib/ImageSearch/opencv_world500.dll` and
  `lib/ImageSearch/vcruntime140.dll`; repository validation pins their approved
  SHA-256 hashes. The bounded GDI+ path remains available if native loading
  fails at runtime.
- Removed all three obsolete bundled Frost strategies
  `Resources/Strats/2_Absolute_Zero.strat`,
  `Resources/Strats/4_FrostModeStrat(Mods)(1.3 fix).strat` and
  `Resources/Strats/FrostModeStrat(Mods)(1.3 fix).strat` because TDS Frost mode
  was reworked. They must stay absent until a developer or tester validates a
  new official strategy; Frost selection and runtime support remain available.
