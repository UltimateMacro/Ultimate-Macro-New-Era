# Recommended repository protection

Apply these settings to the official repository only after the validation
workflow is merged and stable.

## `main`

- Require a pull request and at least one approving review.
- Require conversation resolution.
- Require the `Ultimate Macro CI / validate` status check.
- Require the branch to be current before merge when practical.
- Disable force pushes and branch deletion.
- Limit emergency bypass to trusted maintainers.

## Integration branches

Run CI on every push and pull request. Prefer pull requests for non-trivial
changes, and require a second reviewer for updater, security, remote-control,
network, packaging, dependency, and binary changes.

The existing `.github/CODEOWNERS` file remains unchanged. Maintainers should
verify that both listed owner identities are active and that sensitive paths
such as `.github/workflows/`, `submacros/updater.ahk`,
`submacros/safe_update.ps1`, `DEPENDENCIES.md`, and `SECURITY.md` receive an
appropriate owner review. Do not add placeholder teams to CODEOWNERS.
