# Release process

Official releases must be reproducible from a reviewed source commit.

## Source and release are different products

The source tree contains tests, documentation, GitHub configuration, and developer tooling.

The release ZIP contains only files needed by users at runtime.

Never publish a repository ZIP as `TDS_Macro.zip`.

## Candidate flow

1. Freeze a `release/<version>` branch from reviewed `integration`.
2. Confirm source version and release metadata agree.
3. Run the complete automated suite.
4. Build `TDS_Macro.zip` with `tools/build_release.py`.
5. Validate the package with `tests/test_release_package.py`.
6. Run the manual QA matrix against the exact built ZIP.
7. Calculate and retain SHA-256 evidence.
8. Promote the reviewed commit to `main`.
9. Publish the exact validated ZIP as the release asset named `TDS_Macro.zip`.

Never rewind `main` to recreate an older version. If a historical release branch was removed, restore it by pointing `release/<version>` at the exact historical release commit.

## Preserved history

Repository-v2 preserves:

- `release/1.3.5` at `c2e168a6dfc41d0d13cf5968ace2b804f47ef00b`.
- `release/1.4.0` at `55b1c9e3d04d054093462a2b02d0522e5d75e636`.

These refs preserve release history without changing the current `main` line.

## Package invariants

A release must not contain Git metadata, tests, developer tools, Markdown documentation, Python source/cache files, batch wrappers, repository plans/QA notes, logs, screenshots, personal state, tokens, webhook URLs, or private links.

Runtime PowerShell helpers remain allowed when the application actually invokes them.

## Updater contract

The updater expects the official repository release endpoint, an asset named exactly `TDS_Macro.zip`, a valid GitHub `sha256:` digest, and a payload that passes runtime validation before replacement.

A failed update must leave the previous installation recoverable.

## Automation policy

The repository release workflow builds and validates artifacts but does not publish them automatically. Publication remains an explicit release-owner action after QA signs off on the exact artifact.
