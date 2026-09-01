# Reported runtime QA follow-up — 2026-09-01

Target: continue `qa/reported-runtime-fixes` after local commit `55dfaf3` and
publish only that QA branch to the `origin` fork for a PR into `dev`. Never
merge or push directly to `main`; preserve Darksen as Original Creator and the
GPL-3.0 attribution.

## Follow-up findings and constraints

- `Resources/Strats/2_Absolute_Zero.strat` is the third obsolete bundled Frost
  strategy. It must remain deleted together with the two Frost defaults already
  removed by `55dfaf3`; no Frost strategy may be restored automatically until a
  developer or tester supplies and validates a new official strategy.
- The official runtime package requires the reviewed
  `lib/ImageSearch/opencv_world500.dll` and
  `lib/ImageSearch/vcruntime140.dll` files. Their approved SHA-256 values are
  `7bc06231bf3cfd287e0b6853a78f78e00ceb58266f3cb49642f428ea6f4d1518`
  and `d1f4225df2cd877dbf130d5668a021dce3f94118455ff5ec952061c30afc9ce7`.
- Community strategy refresh must remain enabled in extracted official
  releases, but must not contact or mirror `main` when `A_ScriptDir\.git` is a
  directory (normal checkout) or a file (linked Git worktree).
- `Resources/Strats/SUICIDE_MINIGUNNER_GEM_EXP_FARM.strat` is outside the
  change scope. Preserve its bytes and line endings.
- Numbers-for-Hotbar OFF behavior and the AutoHotkey 2.0.12/2.0.26 difference
  remain manual QA items; source validation will use the immutable verified
  AutoHotkey 2.0.26 toolchain.

## Follow-up atomic commit plan

1. `docs: revise reported runtime QA follow-up plan`
   - Record the corrected three-strategy and required-DLL packaging policy.
   - Record the Git checkout/worktree refresh boundary and remaining manual QA.
2. `fix: skip community strategy sync in Git checkouts`
   - Detect both `.git` directories and linked-worktree `.git` files before any
     community network request.
   - Preserve the six-hour transactional refresh unchanged for release trees.
   - Add regression contracts for both development checkout forms and release
     behavior.
3. `build: finalize reported runtime package contents`
   - Commit the two exact reviewed DLLs and their required hashes.
   - Retire `2_Absolute_Zero.strat`, completing the exact three-file Frost
     cleanup without touching any unrelated `.strat` file.
   - Update packaging/repository validation contracts for the final inventory.
4. `docs: record final runtime packaging and QA gates`
   - Update `CHANGELOG.md`, dependency policy, testing notes, and this plan with
     the final package behavior and validation evidence.

## Follow-up verification gates

- Run dependency sync, Python compilation, all Python contract/validator/lint
  entrypoints, PowerShell parser validation, the updater smoke suite, and
  AutoHotkey 2.0.26 `/Validate`.
- Run `git diff --check`, confirm both DLL hashes from the committed objects,
  confirm the exact remaining strategy inventory, and verify
  `SUICIDE_MINIGUNNER_GEM_EXP_FARM.strat` is byte-identical to `55dfaf3`.
- Confirm Darksen/Original Creator and GPL-3.0 notices remain present.
- Push only `qa/reported-runtime-fixes` to `origin`, then create a PR targeting
  `dev` without merging it. Manual Roblox QA remains required for Hotbar OFF,
  live image/timing behavior, and comparison with the bundled AutoHotkey 2.0.12
  runtime.

## Follow-up execution status

- [x] Plan revised in `08ec33c`.
- [x] Git checkout/worktree community refresh blocked with regression contracts
  in `6363085`; extracted releases retain the existing refresh path.
- [x] Three-strategy Frost cleanup and both hash-pinned runtime DLLs finalized
  in `40b820e`.
- [x] Changelog, dependency policy, README, testing matrix, and validation plan
  updated for final QA handoff.
- [ ] Manual Roblox validation remains open for Numbers for Hotbar OFF, live
  image/timing scenarios, and AutoHotkey 2.0.12 versus 2.0.26 behavior.

---

# Reported runtime QA hotfix — 2026-09-01

Target: PR #30 head `36542adc5c63d384a9a4ad71b780c8d3afd120f8`, branch
`qa/reported-runtime-fixes`, local QA only. Preserve the partially-applied fixes;
do not push, merge, stash, reset, or replace the checkout wholesale.

## Audit findings that constrain the implementation

- The Easy/mode loop still needed one deadline created outside the retry loop;
  Play rediscovery may recover the menu but must never reset that deadline.
- Native OpenCV remains optional. The existing GDI+ bitmap helpers can provide
  bounded multi-scale matching without shipping another unreviewed binary.
- Image capture is SCREEN-based, while all returned matches and mouse actions
  in Main are Roblox CLIENT-based. Window origin must not be added to results.
- Auto Equip's search-bar region reused `rh` as its width. Scale candidates
  must remain fractional at 1366x768 and 1280x720.
- Existing bundled strategies demonstrate the legacy path convention:
  Juggernaut stores `3` and Hacker stores `4` (last shared level). New recordings
  must store `4`/`5` as the first path-specific level, while replay translates
  only the known legacy defaults. Custom tower IDs retain their supplied value.
- There are exactly three path-branch decisions to unify: recorder region,
  replay region, and replay hotkey. All currently use `nextLevel > pathLevel`.
- The partial DJ regression test starts at `SetDJTrack(track)` and can match a
  call. Tests must extract the definition marker `SetDJTrack(track) {`.
- Recording currently captures valid geometry at start but writes the geometry
  seen at save time. Persist the recording-start client size instead.
- PR #30's useful stale-ID, SellTower cleanup, Arcade region, bounded-upgrade,
  Support Caravan, watchdog/resource and coordinate fixes remain subject to the
  final contract/security/runtime review.

## Atomic local commit plan

1. `fix: stabilize runtime detection and recovery`
   - Complete the absolute mode-selection deadline and bounded Play recovery.
   - Harden GDI+ multi-scale fallback metadata/candidates and client/screen
     bounds, Auto Equip geometry, map stabilization, Ready verification, Frost
     image/OCR scrolling, watchdog progress phases, and recording geometry.
   - Normalize raw Click, CloneTower, BrawlerReposition and existing SpawnTower
     replay exactly once from saved strategy dimensions.
2. `fix: correct path tower and DJ behavior`
   - Introduce one path-level resolver shared by all three decision sites.
   - Store the new first-path-specific semantic in recordings while translating
     the known legacy 3/4 values for old Juggernaut/Pursuit/Kingpin/Hacker files.
   - Make DJ UI reopening, track search, cooldown handling and state restoration
     bounded and truthful.
3. `test: cover reported runtime regressions`
   - Replace brittle string checks with function-body extraction and assert every
     requested deadline, coordinate, scale, path, state/resource and deletion
     contract. Add the suite to CI without weakening existing contracts.
4. `docs: document QA fixes and manual validation`
   - Update README, TESTING, CHANGELOG and dependency notes with path semantics,
     supported/recommended resolutions, optional OpenCV behavior and Roblox QA.
5. `chore: remove outdated frost strategies`
   - Delete only the two exact tracked default Frost `.strat` files in its own
     commit after runtime/tests/docs pass. No wildcard or user-strategy cleanup.

## Verification gates

- Compile and run all Python contracts/validators and strategy lint.
- Parse all PowerShell, run updater smoke tests, and validate all AHK entrypoints
  with a locally installed or immutable hash-verified AutoHotkey v2 binary.
- Run `git diff --check`, inspect every final hunk, verify no relevant legacy
  path comparison remains, and confirm the only `.strat` deletions are the two
  named obsolete Frost defaults.
- Document Windows/Roblox-only acceptance separately; automated checks cannot
  validate live TDS artwork, input timing, DPI virtualization or camera state.

---

# Selective pre-QA port plan

## Audit baseline and constraints

- CLEAN: `qa/pre-release-audit-clean` at `8dbf2a3`, directly tracking
  `upstream/main`.
- FULL reference: `backup/pre-qa-hardening` at `b7f4ac3`.
- Common ancestor: `7637737`. CLEAN also contains upstream commits `8206ab9`
  (`StrategyHeight := 1080`) and `8dbf2a3` (watchdog bitmap ownership fixes).
- FULL is reference material only. Do not merge it, cherry-pick it wholesale,
  push it, or import unrelated/WIP files.
- Runtime changes will be applied as minimal manual hunks. The protected
  upstream behaviors listed in the task will be covered by source contracts
  before or alongside further runtime edits.

## Findings that determine the port

### Fresh-checkout gaps

The CLEAN tree cannot pass AutoHotkey load validation as checked out:
`Main.ahk` directly includes `lib/OCR.ahk`, `lib/JSON.ahk`, and
`lib/Roblox.ahk`, but those files are absent. OCR and JSON are third-party
source dependencies; Roblox.ahk is a small project-local helper already
required by Main, ImageSearch, watchdog, and the auxiliary macros.

The CLEAN tree also omits runtime PNGs that current code searches for or loads
in the GUI. FULL's 55 added PNGs were compared with the official New Era
`v1.3.3` `TDS_Macro.zip` release asset. The release asset SHA-256 is
`6d4cae2e3be38b4df70dc38be84c38cef89f1086d6db7f530d210762fc5cdde3`,
and all 55 FULL PNGs are byte-for-byte matches. Only the 47 files actually
needed by current CLEAN code will be restored.

### Dependency and binary disposition

| Item | Required by | Evidence | Decision |
| --- | --- | --- | --- |
| `lib/OCR.ahk` | Main/watchdog OCR calls and direct includes | Descolada OCR 2.0.0, immutable commit `15154d1477eb21ade15dc82a62594053face757f`, Git blob `8b143a4df95e4a447389434c4f75017235339a44`, MIT | Do not copy from FULL. Add a reproducible, hash-verifying setup/CI sync. |
| `lib/JSON.ahk` | Discord responses, GitHub responses, updater release metadata | thqby JSON 1.0.7, immutable MIT source commit `4d1fe28493bcb665d7fcccce1289ed9a36df4ff0`, Git blob `d384f62d611ffdbd16e4fcfb97fc32ec4e4e41d5` (identical to FULL) | Do not copy from FULL. Fetch directly from the original MIT source with blob verification. |
| `lib/Roblox.ahk` | Main, ImageSearch, watchdog, auxiliary macros | Project-local GPL-3.0 helper introduced by FULL commit `5dba00f`; CLEAN already calls every public helper | Port the focused helper source and cover its coordinate contract. |
| `opencv_world500.dll` | Optional native `image_search.dll` backend | 80,108,032 bytes; version 5.0.0; SHA-256 `7bc06231bf3cfd287e0b6853a78f78e00ceb58266f3cb49642f428ea6f4d1518`; unsigned; matches official New Era v1.3.3 package. OpenCV source is Apache-2.0, but the DLL's exact build recipe/source provenance and notices are not in this repository. | Reject from the QA candidate. Keep/test the GDI+ fallback. A reproducible OpenCV build/package review is separate work. |
| `vcruntime140.dll` | Native OpenCV backend | 178,616 bytes; version 14.51.36247.0; SHA-256 `d1f4225df2cd877dbf130d5668a021dce3f94118455ff5ec952061c30afc9ce7`; valid Microsoft signature; matches official New Era v1.3.3 package | Do not commit. Prefer the official Microsoft Visual C++ Redistributable when/if the native backend is approved. |
| `lib/ImageSearch/image_search.dll` and `msvcp140.dll` | Existing optional native backend | Already tracked upstream; SHA-256 values `346d25b9baf582b4cd5550fceaa57f4b1e18f10ae38007ba52ccd07bd790221e` and `7c26614e1d733892c2deac7e245ce115504b1d80592dd0a01b08e3e5a55f89ca` | Preserve unchanged. Document their incomplete provenance; do not broaden this port into a binary replacement. |

Primary provenance references:

- <https://github.com/Descolada/OCR/tree/15154d1477eb21ade15dc82a62594053face757f>
- <https://github.com/thqby/ahk2_lib/tree/4d1fe28493bcb665d7fcccce1289ed9a36df4ff0>
- <https://github.com/opencv/opencv/releases/tag/5.0.0>
- <https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist>
- <https://github.com/DarksenDev/tds-macro/releases/tag/1.3.3>

## Changes to port

### 1. Reproducible runtime prerequisites

- Add FULL's `.gitignore`, adapted to ignore reproducibly fetched OCR/JSON
  sources and local QA/update state.
- Add `tools/sync_dependencies.ps1`, but source JSON directly from thqby's MIT
  repository rather than through the GPL Natro mirror. Verify immutable Git
  blob IDs before installing either source file.
- Add `lib/Roblox.ahk` because CLEAN directly requires it and cannot load
  without it.
- Add `DEPENDENCIES.md` with source, version, integrity, license, binary, and
  fallback findings.
- Restore these exact code-required PNGs from the verified official v1.3.3
  release (the files are identical in FULL):

  - `Resources/3.png`, `Resources/4.png`, `Resources/5.png`
  - `Resources/Badlands II.png`, `Resources/Casual.png`,
    `Resources/Easy.png`, `Resources/Fallen.png`, `Resources/Frost.png`,
    `Resources/Intermediate.png`, `Resources/Molten.png`,
    `Resources/Pizza Party.png`, `Resources/Polluted Wasteland II.png`,
    `Resources/Voidcore.png`
  - `Resources/Claim.png`, `Resources/Disconnected.png`,
    `Resources/GetMore.png`, `Resources/PlayAgain.png`,
    `Resources/Restart.png`, `Resources/Restart2.png`,
    `Resources/Solo.png`, `Resources/SpecialMode.png`,
    `Resources/Veto.png`, `Resources/YouLost.png`
  - `Resources/cancel.png`, `Resources/claim_c.png`,
    `Resources/claimreward.png`, `Resources/close.png`,
    `Resources/close_freerewards.png`, `Resources/confirm.png`,
    `Resources/disconnected2.png`, `Resources/discord.png`,
    `Resources/e_prompt.png`, `Resources/equip.png`,
    `Resources/github.png`, `Resources/golden.png`,
    `Resources/map_selection.png`, `Resources/next.png`,
    `Resources/notgolden.png`, `Resources/notnow.png`,
    `Resources/open.png`, `Resources/searchbar.png`,
    `Resources/searchbar_items.png`, `Resources/searchbar_modifiers.png`,
    `Resources/skip.png`, `Resources/triumph.png`,
    `Resources/use_revive_ticket.png`, `Resources/youtube.png`

### 2. Safe QA infrastructure

- Add a Windows GitHub Actions validation workflow with read-only repository
  permissions, a commit-pinned official checkout action, dependency sync,
  Python compilation, source contracts, repository integrity validation,
  strategy lint, updater parse/smoke tests, and AutoHotkey v2 `/Validate`.
  AutoHotkey will be downloaded from its official immutable release and its
  archive SHA-256 verified instead of executing the unpinned vendored 2.0.12
  binaries.
- Add `tests/validate_repo.py`, adapted so approved fallback operation passes,
  required source/resources fail when absent, unapproved OpenCV/VC runtime
  binaries fail, conflict markers/secrets/generated state are detected, and
  the updater/coordinate contracts are checked.
- Add `tests/lint_strategies.py` for the current allow-listed strategy grammar.
- Add `tests/test_source_contracts.py` covering the protected upstream fixes:
  UpgradeDelay load/save, UpgradeTowerGBKey fallback/save, caller-owned
  screenshot bitmaps, invalid-coordinate OCR fallback, `pBitmapInfo`
  disposal, webhook/bot precedence, retry object lifecycle, decimal
  formatting, and `StrategyHeight := 1080`.

### 3. Confirmed runtime hardening (minimal hunks)

- `Main.ahk`:
  - replace Ready's broad green `PixelSearch` click fallback with bounded,
    rechecked `ready_gs.png` detection; unlike FULL, trust the normalized
    client-coordinate contract instead of subtracting the client origin a
    second time;
  - point community strategies to the verified current path
    `UltimateMacro/Ultimate-Macro-New-Era/contents/Resources/Strats?ref=main`
    (FULL's `contents/Strategies` path is also 404) and abort on zero or partial
    downloads before deleting the old managed set;
  - let webhook batches smaller than 20 send after a two-second collection
    window instead of rescheduling forever;
  - pass the `HGLOBAL` handle, not its locked pointer, to `GlobalSize`.
- `lib/ImageSearch/ImageSearch.ahk`: preserve the existing implementation and
  change only the fallback capture/return coordinate hunks so capture uses the
  Roblox client rectangle in screen space while results remain client-relative.
  Do not add the native DLLs or wholesale FULL diagnostics rewrite.
- `lib/Discord.ahk`: centralize bounded synchronous request attempts for
  transport errors, HTTP 429, and 5xx responses; use `Retry-After`/Discord JSON
  delay hints with a cap; construct a fresh WinHttpRequest per attempt; and fix
  multipart stream/HGLOBAL cleanup without taking ownership of caller bitmaps.
- `submacros/watchdog.ahk`: preserve upstream screenshot ownership, OCR
  fallback, bitmap disposal, condition precedence, and formatting; add status-
  aware bounded webhook retry plus multipart stream release and correct
  `GlobalSize(hData)`.
- Do not port FULL's broad font substitution, Roblox keyboard-layout timer,
  or unrelated Main refactors because they are not confirmed release blockers.

### 4. Transactional updater

- Replace the delete-first `update.bat` behavior with the thin safe wrapper.
- Port `submacros/safe_update.ps1` and `submacros/updater.ahk` as reviewed
  minimal files, targeting New Era releases, selecting a ZIP asset, comparing
  numeric versions, validating archive paths/runtime contents/version, staging
  before replacement, preserving user strategies, retaining a rollback backup,
  refusing Git worktrees, and restoring on failure.
- Tighten FULL's implementation by requiring a valid SHA-256 digest (the
  GitHub release API currently supplies one) and verifying that `MacroDir` is a
  real macro install before moving it.
- Add/update `tests/safe_updater_smoke.ps1` for bad checksum, missing checksum,
  version mismatch, Git checkout refusal, valid update, strategy conflicts, and
  rollback-backup preservation. Tests use only generated temporary installs and
  a loopback HTTP server; they never touch the working tree installation.

### 5. QA and security documentation

- Add/adapt `SECURITY.md`, `TESTING.md`, `CONTRIBUTING.md`, the structured bug
  report, PR template, and branch-protection guidance.
- Document dependency bootstrap, fallback backend expectations, manual Ready/
  image-detection, watchdog/webhook, updater, settings, recording, and full-run
  QA without requiring real Discord credentials in automated checks.

## Rejected or deferred FULL content

- Reject `.github/workflows/vendor-dependencies.yml`: it writes commits and
  pushes from CI, outside this audit's authority and supply-chain policy.
- Defer `.github/workflows/release-package.yml`: release mutation and package
  publication need a separate owner-reviewed release task after QA.
- Reject `AUDIT_PLAN.md`, `docs/AUDIT_NOTES.md`, `docs/CI_TRIGGER_NOTE.md`, and
  `docs/PRIVATE_BRANCH.md`: private-branch/WIP history is not release content.
- Defer `tools/DetectionDiagnostics.ahk` and
  `tools/GenerateDiagnosticReport.ps1`: useful but not required for the safe
  validation/runtime fixes and coupled to the broader FULL ImageSearch tooling.
- Reject `tools/sync_release_runtime.ps1` and any bulk resource/binary sync:
  this port uses an explicit resource allowlist and no optional native DLLs.
- Defer the eight unreferenced FULL PNGs: `Resources/Crossroads.png`,
  `Resources/DontSkip.png`, `Resources/Sell.png`,
  `Resources/claimdailyreward.png`, `Resources/claimed.png`,
  `Resources/coins.png`, `Resources/gem.png`, and `Resources/xp.png`.
- Reject all Strategy Lab, Remote 2.0, experimental transforms/runners,
  diagnostics bundles, vendored package directories, unrelated assets, and WIP
  files not listed above.

## Atomic commit plan

1. `docs: add pre-QA port plan`
2. `build: restore verified runtime prerequisites`
3. `ci: add repository validation`
4. `test: add runtime regression contracts`
5. `fix: port confirmed runtime hardening`
6. `fix: harden transactional updater`
7. `docs: add QA checklist and security notes`

Commits may be split further only if needed to keep a single purpose and clear
rollback. No commit will be pushed or merged.

## Verification after each significant change

- `python -m py_compile` for Python validators.
- `python tests/test_source_contracts.py .`
- `python tests/validate_repo.py .`
- `python tests/lint_strategies.py .`
- PowerShell parser validation and `pwsh ./tests/safe_updater_smoke.ps1` when
  updater files exist/change.
- AutoHotkey v2 `/Validate` using the verified official 2.0.26 binary after
  pinned OCR/JSON sync. No Roblox/gameplay automation will be launched.
- `git diff --check`, secret/personal/generated/binary/resource scope audit,
  final status/diff/stat/log commands requested in the task.

Manual QA remains required for Roblox image clicks at representative client
sizes, a full strategy run, recording/settings persistence, webhook/bot sends
with disposable credentials, watchdog recovery, and a disposable-install
updater test.

## Release updater repository migration

- Point only latest-release discovery and release-asset allowlists at
  `DarksenDev/tds-macro`.
- Keep the development and community strategy source on
  `UltimateMacro/Ultimate-Macro-New-Era`.
- Extend repository/source contracts to require the official release endpoints
  and reject the retired release lookup/download paths.
- Run all repository, PowerShell, updater-smoke, and AutoHotkey validation gates.
- Leave the result uncommitted and unpushed for manual review as requested.
