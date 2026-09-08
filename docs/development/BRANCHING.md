# Branching model

The private development mirror is organized around a stable line, a shared integration line, personal developer workspaces, and short-lived task branches.

## Long-lived branches

### `main`

Stable/public-ready mirror. Do not use it as a scratch branch.

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
feature/fix/refactor branch
  ^
  | created from a synced workspace
dev/<handle>
```

## Historical branches

`archive/*` and `backup/*` exist as safety history. Do not base new work on them and do not delete them during normal cleanup. Remove historical refs only as a separate explicitly approved maintenance task.

## Rules

- No force-push to `main` or `integration`.
- No direct runtime development on `main`.
- Keep one purpose per task branch.
- Delete short-lived task branches after merge.
- Sync personal branches frequently to prevent long-lived divergence.
- Release branches are frozen except for blocker fixes and release metadata.
