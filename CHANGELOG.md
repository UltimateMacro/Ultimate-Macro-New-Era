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

### Packaging

- Restored the reviewed portable fallback policy; `opencv_world500.dll` remains optional and the copied `vcruntime140.dll` is removed from this QA candidate.
- Removed the obsolete bundled strategies
  `Resources/Strats/4_FrostModeStrat(Mods)(1.3 fix).strat` and
  `Resources/Strats/FrostModeStrat(Mods)(1.3 fix).strat` because TDS Frost mode
  was reworked. Frost selection and runtime support remain available.
