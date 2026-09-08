# Repository v2 super-merge plan

Target branch: `refactor/repository-v2-supermerge`

Baseline: official `main` at `ef19b521c83de04c60532239e97099ddfcfaa5b6`, runtime version `1.4.0`.

Goal: bring the validated repository-v2 organization, branch model, documentation, CI, and release-package tooling into the official New Era repository without changing gameplay/runtime behavior.

## Release history preservation

The repository has already advanced beyond the 1.3.5 release point. The super-merge must not rewind `main`.

After the organization PR is merged:

- `release/1.3.5` preserves the exact 1.3.5 release commit `c2e168a6dfc41d0d13cf5968ace2b804f47ef00b`.
- `release/1.4.0` preserves the 1.4.0 release commit `55b1c9e3d04d054093462a2b02d0522e5d75e636`.
- `main` remains the current stable/public-ready line.
- `integration` becomes the shared staging line.
- `dev/<handle>` branches become long-lived personal workspaces.

This keeps 1.3.5 available as an exact historical release line while preserving every later 1.4.0 change already present on main.

## Atomic commit plan

1. **Port repository v2 organization**
   - Bring over the validated README, contribution flow, issue forms, PR template, CODEOWNERS, docs, version metadata, package builder, package validator, and CI/release workflows.

2. **Adapt repository v2 to the official repository**
   - Remove private-mirror wording.
   - Document the official branch model and preserved 1.3.5/1.4.0 release lines.
   - Record the repository/tooling change in the changelog.

3. **Validate the super-merge candidate**
   - Run source/runtime regression contracts.
   - Run repository and strategy validation.
   - Run PowerShell/updater/AutoHotkey validation.
   - Build and validate `TDS_Macro.zip`.
   - Require diff hygiene to pass.

4. **Promote and seed organized branches**
   - Merge the reviewed candidate into `main`.
   - Create `integration` and `dev/<handle>` from the merged main commit.
   - Create immutable historical release pointers for 1.3.5 and 1.4.0.
   - Do not delete history or force-push any branch.

## Repository invariants

- No gameplay/runtime behavior change is intended by this organization merge.
- `main` is never rewound to an older release.
- Runtime binaries and dependencies remain pinned and validated.
- Release artifacts exclude developer-only files and metadata.
- Runtime PowerShell helpers required by the application remain package-eligible.
- Existing updater integrity, rollback, secret-redaction, and strategy-preservation contracts remain intact.
- Darksen attribution and GPL-3.0 licensing remain unchanged.

## Rollback

Before merge, abandon the candidate branch. After merge, revert the organization merge commit if needed. Historical release branches are additive safety references and do not rewrite existing history.
