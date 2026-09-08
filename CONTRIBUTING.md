# Contributing to Ultimate Macro: New Era

Ultimate Macro automates a live game UI, so small changes can affect timing, recovery, image detection, and user state. Prefer focused changes with explicit evidence over large mixed patches.

## Branch workflow

The private development mirror uses the following model:

- `main`: stable/public-ready mirror.
- `integration`: shared staging branch.
- `dev/<handle>`: long-lived personal workspace.
- `feature/<handle>/<topic>`: new behavior.
- `fix/<handle>/<topic>`: bug fixes.
- `refactor/<topic>`: behavior-preserving structural work.
- `release/<version>`: frozen release candidate.
- `archive/*` and `backup/*`: historical safety refs; never use as normal development bases.

Before starting work, sync your personal branch from `integration`. Open a focused task branch for non-trivial work and merge it back through review.

See [docs/development/BRANCHING.md](docs/development/BRANCHING.md).

## Pull requests

A pull request should explain what changed, why, affected runtime areas, tests run, manual validation, and risk/rollback notes.

Avoid whitespace-only rewrites in the same PR as behavior changes. High-risk updater, security, remote-control, networking, packaging, dependency, or binary changes require a second reviewer.

## Runtime changes

For placement, upgrade, sell, TimeScale, recorder, or recovery changes, preserve the action lifecycle:

```text
ACTION -> OBSERVE -> VERIFY -> SUCCESS
                 \-> RETRY / RECOVER / FAIL
```

Do not mark an action successful merely because an input was sent.

For image detection, document the template, search region, threshold/fallback, client size, Windows scaling, window position, and relevant display conditions.

For watchdog or networking code, retries must be bounded. Resource ownership and cleanup must be explicit for native handles, COM objects, processes, timers, and temporary files.

Strategy files are data consumed by an allow-listed parser. Never introduce arbitrary expression or code execution through strategy loading.

## Testing

Run the automated preflight documented in [TESTING.md](TESTING.md), then run the relevant manual regression matrix.

Behavior changes need regression coverage where practical, repository validation, strategy lint when applicable, AutoHotkey validation, and a targeted Windows/Roblox runtime check.

## Dependencies and secrets

New binaries require provenance, version, SHA-256, license, justification, and a reproducible acquisition/build decision in `DEPENDENCIES.md`.

Never commit or attach Discord tokens, webhook URLs, Roblox private/VIP server links, AppData settings, personal screenshots, unsanitized logs, or recorded personal state.

## Releases

Do not hand-assemble release ZIPs. Use the repository release builder and validate the artifact before publication.

See [docs/development/RELEASE_PROCESS.md](docs/development/RELEASE_PROCESS.md).
