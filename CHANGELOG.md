# Ultimate Macro v1.3.5

**Release improvements:**

- Bundles the portable Strategy Lab WebView editor as `StrategyLab.exe` with its
  isolated `_app` runtime. It can safely open, inspect, and save copies of
  `.strat` files without starting or stopping gameplay.
- Preserves the existing F2 stop behavior and all resolution/geometry values.
- Keeps Official Remote consent, DPAPI-protected credentials, token rotation,
  and the server-side release-access checks intact.
- Release validation now works both from a Git checkout and from an extracted
  release archive, with Strategy Lab executables and WebView loaders hash-pinned.

# Ultimate Macro v1.3.4b

**Improvements:**

- Improved placement reliability with bounded retries and safer action confirmation.
- Improved upgrade handling so the macro waits for reasonable UI evidence before updating tower state.
- Improved Juggernaut and path-tower upgrade reliability with safer settle timing.
- Improved Timescale handling for Confirm, Get More, and zero-ticket situations.
- Improved Auto Equip confirmation and second-run cleanup.
- Improved map selection, rejoin recovery, F2 stopping, and held-input cleanup.
- Improved difficulty selection by keeping OCR inside the mode cards and refusing ambiguous Hardcore unlock text.
- Added focused diagnostics for ambiguous actions and bounded recovery paths.

**Bug Fixes:**

- Fixed towers being placed twice when the first placement succeeded but its UI was missed.
- Fixed non-cancelled placement failures stopping the entire strategy; the next step now continues after bounded placement handling.
- Fixed lagging existing tower panels being treated as fatal placement failures.
- Fixed failed or unaffordable upgrades being counted as successful.
- Restored bounded retry behavior for upgrades that are not confirmed on the first click.
- Fixed map selection and recovery paths getting stuck in repeated loops.
- Fixed stale tower, Timescale, and UI state carrying into the next run.
- Fixed Auto Equip reporting success when the tower was not actually equipped.
- Fixed stop cleanup leaving mouse or movement input held.
- Fixed mode selection getting stuck after “Joining Easy...” with a bounded, diagnosable party-size wait.

**Download Now!**  
[Click me to download](https://github.com/UltimateMacro/Ultimate-Macro-New-Era/releases/download/v1.3.4b/TDS_Macro_1.3.4b.zip)

@Update Ping

# Changelog

## Unreleased — reported runtime QA hotfix

### Added

- Official Discord Remote Control page with private per-account linking, status,
  start, stop and screenshot commands through EngineerBot.
- Random per-installation identity, Windows DPAPI token protection, automatic
  token rotation and a clear privacy/consent notice. No hardware ID is collected.

### Fixed

- Watchdog PID cleanup raising `VarUnset` after an incomplete launch, repeated
  cleanup/start cycle, or an early Main exit. Launch now publishes only a
  successful local PID, while cleanup is idempotent, path-scoped, and logged.
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
- Auto Settings falsely classifying Roblox-normalized XML as foreign when the
  file's BOM or unrelated serialization changed but every macro-managed value
  remained correct. Exact applied hashes remain the fast path; a strict
  managed-node semantic fallback now handles this state without weakening the
  verified original backup.
- Auto Settings recovery now fails closed when backup provenance is incomplete,
  preserving metadata-only or backup-only evidence instead of treating it as a
  clean state.
- Persistent `RobloxPlayerBeta.exe --launch-to-tray` processes no longer block
  a verified restore after gameplay ends. Visible games and process-inspection
  failures remain active/fail-closed.
- Terminal Roblox launch, lobby, join, map, ready and TimeScale failures now
  propagate to the strategy owner before later input can run. Camera alignment
  also requires a live Roblox HWND and CLIENT geometry and always releases the
  right mouse button.

### Improved

- Party Mode preflight validation now blocks impossible Host/Member setups before a run starts.
- Party invites use scaled client offsets, serialized invite typing, fresh member recounts, bounded retries, and explicit host/member watchdog phases.
- Strategy cards now have a draggable scrollbar in addition to wheel scrolling.
- Webhook URL validation is debounced instead of issuing a synchronous request on every keystroke.
- Rotation keeps Auto Equip visibly locked on instead of disabling the checkbox with ambiguous OS styling.
- Primary action buttons use the existing gradient-button system with real disabled-state click guards.
- Stop/record cleanup releases named and scan-code inputs and stops recurring runtime timers before teardown.
- Auto Settings is opt-in for 1.3.4, requires a verified original backup before changing Roblox XML, writes atomically, and restores only after Roblox actually exits.
- Pending Auto Settings restores survive normal macro shutdown; re-enabling the feature cancels stale restore requests safely.
- Auto Settings now validates XML with the Windows parser, records versioned
  backup provenance and SHA-256 identities, and refuses unknown, altered, or
  superseded restore state without deleting recovery evidence.
- Auto Settings is applied only after Roblox is confirmed closed at the single
  pre-launch boundary; generation tokens and an inter-process mutex prevent an
  older restore helper from overwriting a newly applied configuration.
- Ordinary F2/recording/strategy cleanup no longer disables the persistent
  Discord Bot command timer. Scrollbar and debounced webhook timers are now
  stopped explicitly during GUI/process teardown.

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
- Runtime/source and transactional-updater manifests now require the mandatory
  `lib/auto_settings.ahk` include; incomplete update ZIPs are rejected before
  the existing installation is moved.