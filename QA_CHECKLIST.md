# Pre-release QA checklist

Candidate commit: __________  Release/version: __________  Tester: __________

Environment: Windows __________  Scaling __________  Roblox client __________

## Automated gates

- [ ] Dependency sync succeeds from a clean checkout.
- [ ] Python compilation and source regression contracts pass.
- [ ] Repository integrity validator passes with only documented warnings.
- [ ] All strategy files pass the allow-listed grammar linter.
- [ ] PowerShell parse validation and updater smoke tests pass.
- [ ] AutoHotkey `/Validate` passes for Main and standalone helpers.
- [ ] Final secret, generated-state, binary, resource, and scope audit passes.

## Manual gates

- [ ] Fresh release-style launch succeeds with Discord integrations disabled.
- [ ] Settings persistence and short strategy recording/reload pass.
- [ ] Ready detection passes in a moved Roblox window and at a second client size.
- [ ] One complete strategy reaches post-match handling successfully.
- [ ] Image-driven Equip plus Restart/Play Again behavior passes.
- [ ] Disposable webhook screenshot, queue, retry, and bot screenshot checks pass.
- [ ] Watchdog disconnect/result fallback completes without a crash.
- [ ] Disposable-install updater test preserves strategies and creates a valid rollback backup.
- [ ] No test token, webhook, private-server link, log, or personal configuration remains in the candidate.

## Exit criteria

All automated gates must pass. Any skipped manual gate needs an owner, reason,
and release decision recorded below; security, updater integrity, data-loss, or
repeatable crash failures block release.

Notes / exceptions / evidence:

______________________________________________________________________________

QA decision: [ ] PASS  [ ] PASS WITH NOTES  [ ] BLOCKED
