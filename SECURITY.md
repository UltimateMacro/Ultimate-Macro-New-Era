# Security policy

Ultimate Macro interacts with Roblox, Discord APIs, local files, and an
automatic updater. Reports involving remote commands, update integrity,
credential exposure, or arbitrary file/process execution are high priority.

## Reporting a vulnerability

Do not open a public issue when a report contains exploit details, credentials,
or private links. Use GitHub private vulnerability reporting for the official
repository when available, or contact a maintainer through the team's
established private channel.

Use a public bug report only when it can be reproduced without exposing:

- Discord bot tokens or webhook URLs;
- Roblox private/VIP server links;
- arbitrary command, file-download, or code-execution techniques;
- updater validation, path traversal, or rollback bypasses; or
- a weakness that would place other users at risk before a fix is available.

Security fixes target the current release and `main`. Users of an older build
may be asked to upgrade to receive the fix. No response timeline is promised,
but maintainers should acknowledge and triage sensitive reports privately.

## Security invariants

- Discord controls must remain explicit, allow-listed, authenticated, bounded,
  and auditable. They must not expose a general shell or expression evaluator.
- The updater must require the official named release asset and a valid
  SHA-256 digest, validate before replacement, reject developer checkouts, and
  keep or restore the previous installation on failure.
- Third-party source dependencies must be pinned to immutable revisions.
- New executable or DLL dependencies require documented provenance, version,
  SHA-256, license, and a reproducible acquisition/build decision.
- Logs, screenshots, issues, and diagnostics must be checked for tokens,
  webhook URLs, private-server links, and personal configuration before sharing.

See [DEPENDENCIES.md](DEPENDENCIES.md) for the current dependency and binary
review.
