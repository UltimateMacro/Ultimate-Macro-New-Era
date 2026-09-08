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

## Package invariants

A release must not contain Git metadata, tests, developer tools, Markdown documentation, Python source/cache files, batch wrappers, repository plans/QA notes, logs, screenshots, personal state, tokens, webhook URLs, or private links.

Runtime PowerShell helpers remain allowed when the application actually invokes them.

## Updater contract

The updater expects the official repository release endpoint, an asset named exactly `TDS_Macro.zip`, a valid GitHub `sha256:` digest, and a payload that passes runtime validation before replacement.

A failed update must leave the previous installation recoverable.

## Automation policy

The repository release workflow builds and validates artifacts but does not publish them automatically during this rework. Publication remains an explicit release-owner action until the workflow has been exercised and approved on the official repository.
