## What changed

<!-- Keep behavior changes focused and explain why each changed file is needed. -->

## Risk / affected areas

- [ ] Strategy execution or recording
- [ ] Image detection / Ready flow
- [ ] Watchdog / recovery
- [ ] Discord webhook / bot
- [ ] Settings / persistence
- [ ] Updater / packaging
- [ ] Dependencies / binaries / resources
- [ ] Documentation or CI only

## Testing performed

- [ ] `python tests/test_source_contracts.py .`
- [ ] `python tests/validate_repo.py .`
- [ ] `python tests/lint_strategies.py .`
- [ ] `pwsh ./tools/validate_powershell.ps1`
- [ ] `pwsh ./tests/safe_updater_smoke.ps1` when updater code changed
- [ ] `pwsh ./tools/validate_ahk.ps1`
- [ ] Relevant manual checks from `TESTING.md`

Runtime environment/results:

<!-- Windows version, scaling, Roblox client size, backend, strategy/map, observed result. -->

## Review checklist

- [ ] No secrets, personal configuration, logs, screenshots, or generated state are committed.
- [ ] New dependencies/binaries/resources have provenance, integrity, license, and necessity evidence.
- [ ] Failure paths are bounded and preserve existing data.
- [ ] Ownership and cleanup are explicit for changed GDI+/COM/native resources.
- [ ] Risky behavior has a regression test and a documented rollback.

<!-- Sanitize all logs and screenshots before attaching them. -->
