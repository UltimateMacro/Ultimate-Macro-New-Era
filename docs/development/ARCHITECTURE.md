# Architecture

Ultimate Macro: New Era is currently an AutoHotkey v2 application with a large runtime entry point and supporting libraries/submacros.

## Current layers

```text
Main.ahk
  |
  +-- UI and settings orchestration
  +-- strategy recording / execution
  +-- runtime state and recovery
  |
  +-- lib/
  |    +-- image detection / OCR
  |    +-- Roblox helpers
  |    +-- Discord / Official Remote
  |    +-- logging / profiles / settings helpers
  |
  +-- submacros/
       +-- watchdog
       +-- updater
       +-- transactional update helper
```

## Direction

The long-term goal is to make `Main.ahk` an orchestration/bootstrap layer while moving coherent behavior into smaller modules.

Target conceptual boundaries:

```text
src/core/          lifecycle, state, configuration, logging
src/ui/            windows, controls, reusable UI components
src/automation/    Roblox actions: place, upgrade, sell, TimeScale, matchmaking
src/strategy/      parser, recorder, runner, validation
src/integrations/  Discord, remote control, updater
apps/strategy-lab/ Strategy Lab-specific implementation
```

This is a migration direction, not permission for a rewrite.

## Refactor rule

A module extraction must preserve observable behavior, retain regression coverage, avoid unrelated cleanup, pass the full automated suite, and receive targeted Windows/Roblox runtime validation.

## Action-result contract

Critical runtime actions should converge on an explicit lifecycle:

```text
ACTION -> OBSERVE -> VERIFY -> SUCCESS
                 \-> RETRY -> RECOVER / FAIL
```

Placement, upgrade, sell, TimeScale, matchmaking and recorder state should not infer success solely from a click/key event.

## State ownership

New code should make ownership explicit for process IDs, timers, temporary files, bitmaps/native handles, HTTP/COM requests, strategy execution state, and persistent settings.

Cleanup should be idempotent and scoped to resources owned by the current instance.
