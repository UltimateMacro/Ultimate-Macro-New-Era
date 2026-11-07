# v1.4 contribution QA — pizzaroles24

Integration baseline: `88ea20e1bad14a9debee06907b5d7b85819a33cb` on `shovel-aiden/fix-v1.4`. Keep the [official checklist](../README.md) open until the stated LIVE conditions are met.

## Changes in this contribution

- Keep strategy import and search available in compact and ultra-compact views. The query and selection survive resizing. Same-title strategies display their filenames so their copies can be distinguished in the picker and rotation slots.
- Add a feature finder that reveals and focuses existing controls. Searching does not run actions or change options. The search recognizes English and common Spanish terms.
- Validate the freshly inspected strategy at Start. Both rotation slots are checked; a cached result for the same path cannot admit edited, unsupported content or reject repaired content.
- Export an allowlisted settings-only `.ump` that round-trips through the existing importer. The export omits strategy paths, links and credentials and refuses to overwrite an existing file.

## Upstream overlap

The branch already includes source changes for current lobby dialogs, Easy/Casual labels, a guarded Ready click, exact VIP map search, placement verification and dock status. The [official 1.4.0.41 handoff](QA-1.4.0.41-HANDOFF.md) records a LIVE failure after the VIP picker closed, where the active map could not be proven. Do not relax that exact-match guard or replace these changes with older local code.

## Remaining verification

- Timescale: the local QA derivative unlocked one existing ticket and verified 1× → 1.5× → 2× in the HUD, then completed all 84 Wretched Front steps and placed Enforcer. That is evidence for the local derivative, not this official integration. Port the smallest verified mechanism, test locked/unlocked and Cancel/no-ticket flows, and confirm it on the official base at more than one resolution. Do not copy local ledgers, profiles, automation handoffs, or account artifacts.
- Repeat: one local run reached its result and reentered the lobby. A subsequent automatic entry stopped at Hardcore selection. Repeat is open; verify 3 games from one Start, including docked and undocked geometry, with no purchases or unintended relaunch. Enforcer placement was seen; evolution XP was not measured.
- Validate the official VIP path from lobby to verified map and results, together with Auto Equip, private-session recovery, recording, advanced-settings controls and the GUI at multiple client resolutions.
- The local appearance and Strategy Lab changes are separate ports. The editor can draft Hacker clones and Enforcer relocations locally; these need direct confirmation of the intended tower and resulting identity or position before enabling LIVE playback. Night 3 event routing and Drop Collector are also outside this contribution.
- Updater approval, production dashboard pairing and distribution checks remain in the official handoff. This branch is not a release candidate.

## Offline evidence

13 AutoHotkey suites and 6 syntax targets passed with the bundled AutoHotkey 2.0.31. The engine manifest verified 173 entries and all 10 locale files passed validation. The compact control tests drive the real widgets in hidden windows at 820, 560 and 460 logical pixels. Roblox play and Windows DPI coverage remain separate.

Independent Orca POST review identified four integration issues: duplicate basenames, an obsolete cached denial disabling mouse Start, Recording shortcuts opening only its container, and a hotkey conflict on profile import. Each has a regression case and was corrected before publication.

### Independent audit of the upstream runtime

Claude reviewed the exact baseline in Orca. The source points to four follow-ups: preserve Confirm recognition under hover; recognize the actual post-match action and verify its transition; make client relaunch an explicit recovery path instead of the result of a missing Restart control; and require exact map evidence before committing a Hardcore vote. The audit also flagged fullscreen recovery and recorder key coverage for targeted reproduction. These are source findings and do not close the LIVE checklist.
