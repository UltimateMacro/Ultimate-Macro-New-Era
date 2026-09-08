# Branching model

The official repository is organized around a stable line, a shared integration line, personal developer workspaces, short-lived task branches, and frozen release refs.

## Long-lived branches

### `main`

Current stable/public-ready line. Do not use it as a scratch branch and never rewind it to recreate an older release.

### `integration`

Shared staging line. Completed reviewed work is combined here before promotion.

### `dev/<handle>`

Reserved personal workspace branches:

- `dev/pizzaroles24`
- `dev/ziadod`
- `dev/kronoxxv`
- `dev/banana.dev`
- `dev/itzshovel`
- `dev/salkann`
- `dev/aiden`

A personal branch is not a permanent fork of the project. Keep it close to `integration`.

## Short-lived task branches

Use:

- `feature/<handle>/<topic>`
- `fix/<handle>/<topic>`
- `refactor/<topic>`
- `qa/<handle>/<topic>`
- `release/<version>`

Examples:

```text
feature/ziadod/strategy-lab-search
fix/aiden/timescale-confirmation
refactor/runtime-action-results
qa/nytli/v135-placement-matrix
release/1.3.5
```

## Flow

```text
main
  ^
  | promote after sign-off
integration
  ^
  | reviewed merge
feature/fix/refactor/qa branch
  ^
  | created from a synced workspace
dev/<handle>
```

## Preserved release lines

Historical releases are additive refs, not reasons to rewrite `main`.

- `release/1.3.5` points at the exact 1.3.5 release commit.
- `release/1.4.0` points at the 1.4.0 release commit.

New release branches are frozen after publication except for explicitly reviewed metadata-only corrections.

## Historical branches

`archive/*` and `backup/*` are safety history. Do not base new work on them and do not delete them during normal cleanup. Remove historical refs only as a separate explicitly approved maintenance task.

## Rules

- No force-push to `main` or `integration`.
- No direct runtime development on `main`.
- Never rewind `main` to an older release.
- Keep one purpose per task branch.
- Delete short-lived task branches after merge when safe.
- Sync personal branches frequently to prevent long-lived divergence.
- Release branches are frozen except for blocker fixes before publication or reviewed metadata-only corrections.
