# Contributing to Ultimate Macro: New Era

Runtime automation is sensitive to small game and UI changes, so focused,
testable changes are preferred over mixed refactors.

## Development flow

1. Branch from the current integration branch.
2. Keep one behavioral goal per branch or pull request when practical.
3. Run the automated checks in [TESTING.md](TESTING.md).
4. Manually test the affected runtime behavior in a disposable configuration.
5. Describe the test environment and result in the pull request.
6. Require another team member to review high-risk runtime, updater, security,
   network, packaging, or dependency changes.

Avoid combining whitespace-only rewrites with behavioral changes. Preserve
existing behavior with a regression contract before changing runtime logic.

## Runtime changes

For image detection, document the template, search region, threshold, fallback,
client size, monitor scaling, window position, and color/HDR configuration.

For watchdog or networking code, keep retries bounded and make the owner and
lifetime of GDI+ bitmaps, streams, HGLOBAL allocations, and COM requests clear.

Strategy files are data consumed by an allow-listed parser. New commands must
be added explicitly to the runtime and `tests/lint_strategies.py`; never add
arbitrary code evaluation to strategy loading.

## Dependencies, binaries, and resources

Do not copy an executable, DLL, or resource from a fork merely because it is
present there. New binaries require source/build provenance, version, SHA-256,
license, and a reproducible acquisition decision in `DEPENDENCIES.md`. New
images must have known provenance and a demonstrated runtime reference.

## Secrets and test data

Never commit Discord tokens, webhook URLs, Roblox private-server links,
AppData settings, logs, screenshots, or recorded personal state. Use disposable
credentials for integration tests and sanitize all evidence before sharing.

Test updater and packaging changes only against a disposable extracted install.
A failed update must leave the prior installation recoverable.
