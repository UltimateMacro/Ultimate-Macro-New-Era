# Repository v2 rework plan

Target branch: `refactor/repository-v2`

Goal: make Ultimate Macro: New Era easier to maintain, review, test, package, and hand between developers without changing runtime behavior during the repository-organization phase.

## Atomic commit plan

1. **Document repository v2 migration plan**
   - Replace the historical working-plan dump with this focused migration plan.
   - Define invariants, rollback points, and the branch model.

2. **Refresh project documentation and contribution flow**
   - Rework the README as the public project landing page.
   - Add architecture, branching, release, and QA documentation under `docs/`.
   - Improve issue and pull-request templates.
   - Correct CODEOWNERS metadata.

3. **Add version and release-package contracts**
   - Add a canonical `VERSION` file for build/release tooling.
   - Add a deterministic allow-list release builder.
   - Add release-package validation tests.
   - Keep runtime version behavior unchanged for this phase; CI verifies that the source literal and `VERSION` agree.

4. **Expand CI for the organized branch model**
   - Run CI on main, developer, feature, fix, refactor, release, and integration branches.
   - Validate the release package in CI.
   - Add a build-only release workflow that produces `TDS_Macro.zip` and SHA-256 evidence without publishing automatically.

5. **Create organized developer workspaces**
   - Create a shared `integration` branch from the reviewed repository-v2 candidate.
   - Create long-lived `dev/<handle>` branches for each current developer.
   - Keep feature/fix work short-lived and merge through review.
   - Preserve existing archive/backup branches until a separate cleanup is explicitly approved.

## Repository invariants

- `main` remains the stable/public-ready line.
- This rework does not intentionally change gameplay/runtime behavior.
- No force-pushes or destructive branch cleanup are part of this task.
- Runtime binaries and dependencies remain pinned and validated.
- Release artifacts must never contain Git metadata, tests, docs, caches, Markdown, Python tooling, batch wrappers, or other developer-only files.
- PowerShell files required at runtime remain allowed in releases.
- Existing updater integrity, rollback, and secret-redaction contracts must remain intact.

## Rollback

Every change is isolated on `refactor/repository-v2`. The current private `main` remains untouched. Rolling back the repository rework therefore only requires abandoning or deleting the candidate branch; no history rewrite is necessary.
