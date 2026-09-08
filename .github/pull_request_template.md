## Summary

<!-- What changed and why? Keep unrelated changes in separate PRs. -->

## Branch / scope

- Source branch:
- Target branch:
- Primary owner:
- Related issue:

## Affected areas

- [ ] UI only
- [ ] Strategy recording
- [ ] Strategy parsing / Strategy Lab
- [ ] Placement / upgrade / sell
- [ ] TimeScale
- [ ] Image detection / OCR
- [ ] Matchmaking / recovery / watchdog
- [ ] Discord webhook / Official Remote
- [ ] Settings / persistence
- [ ] Updater / packaging / release
- [ ] Dependencies / binaries / resources
- [ ] Documentation / CI only

## Automated checks

- [ ] `python tests/test_source_contracts.py .`
- [ ] `python tests/test_reported_runtime_fixes.py .`
- [ ] `python tests/validate_repo.py .`
- [ ] `python tests/lint_strategies.py .`
- [ ] `pwsh ./tools/validate_powershell.ps1`
- [ ] `pwsh ./tests/safe_updater_smoke.ps1` when updater code changed
- [ ] `pwsh ./tools/validate_ahk.ps1`
- [ ] Release package test when packaging changed

## Manual runtime validation

- Windows:
- Display scaling:
- Roblox client size:
- Strategy / map:
- Result:

## Risk / rollback

<!-- What can regress? How do we revert safely? -->

## Review checklist

- [ ] Existing behavior is preserved unless the PR explicitly changes it.
- [ ] New/changed behavior has regression coverage where practical.
- [ ] Inputs are validated and retries are bounded.
- [ ] No secrets, personal configuration, logs, screenshots, or generated state are committed.
- [ ] New binaries/resources have provenance, integrity, license, and necessity evidence.
- [ ] Resource/process/timer ownership and cleanup are explicit.
- [ ] Documentation and changelog are updated when user-visible behavior changes.
