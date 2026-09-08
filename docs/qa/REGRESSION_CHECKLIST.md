# Regression checklist

Use the detailed matrix in [TESTING.md](../../TESTING.md) for release sign-off. This page is the short review checklist.

## Core runtime

- [ ] Clean launch and restart.
- [ ] Start / stop / F2 cleanup.
- [ ] Placement verifies success and handles ambiguous positions safely.
- [ ] Upgrades do not advance state without confirmation.
- [ ] Selling reports success only after the tower is actually gone.
- [ ] TimeScale activation is verified and bounded.
- [ ] Matchmaking / map selection / Ready flow recover safely.

## Recorder and Strategy Lab

- [ ] Short recording save/reload.
- [ ] Long recording save/reload without truncated Spawn/Upgrade/Sell steps.
- [ ] Strategy Lab loads, edits, saves, and reopens a strategy without corruption.
- [ ] Invalid or unsupported strategy commands fail safely.

## Resolution and detection

- [ ] 1920×1080 / 100% baseline.
- [ ] One supported non-default client size.
- [ ] Roblox moved away from the desktop origin.
- [ ] OCR/image fallback path remains bounded.

## Integrations

- [ ] Webhook sends once and redacts secrets.
- [ ] Official Remote remains authenticated and bounded.
- [ ] Watchdog starts/stops without PID leakage.

## Release / updater

- [ ] Release ZIP contains only runtime files.
- [ ] `TDS_Macro.zip` package validation passes.
- [ ] Updater refuses invalid digest or incomplete payload.
- [ ] User strategies survive a successful staged update.
- [ ] Rollback restores the previous installation after a simulated failure.

Record Windows version, scaling, Roblox client size, commit/release version, and observed result with the sign-off.
