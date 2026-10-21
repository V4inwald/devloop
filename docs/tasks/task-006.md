---
id: task-006
status: review
branch: task/006-github-arbiter
created: 2026-10-21
owner: lead
implementer: lead
---

# Faire de GitHub l'arbitre : PR, protection, checks requis

## Outcome

`main` can only change through a pull request whose CI checks are green, and
`integrate.sh --pr` is the normal path: it pushes the branch, waits for the
required checks, merges via GitHub, then gates the GitHub merge commit locally.

## Acceptance criteria

- [x] AC1: `integrate.sh --pr` pushes the branch, opens/reuses a PR, waits for the checks, merges with `gh pr merge --merge --delete-branch`, gates the GitHub merge commit locally, updates the local `main`, and records `mode: pr`. `--pr` and `--push` are mutually exclusive; `REQUIRE_PR=true` refuses a local integration.
- [x] AC2: `scripts/devloop/protect.sh` builds a protection payload requiring the `gate` check, direct-push denial and admin enforcement, forbidding force-push/deletion; `--dry-run` is tested without network.
- [x] AC3: `.github/CODEOWNERS` names the contract paths; `.devloop.conf` sets `REQUIRE_PR=true` and `REQUIRE_CI=true`.
- [x] AC4: SKILL, AGENTS, dev-cycle, README and design/04 describe PR mode, the protection, and the bookkeeping path (`state/<sha>` PR) when direct pushes are blocked; the bundle is refreshed and drift-tested.
- [x] AC5: `bash tests/run.sh` passes and the gate is clean.
- [ ] AC6 (post-merge): this task is merged through `--pr`, `protect.sh` is applied, a direct push to `main` is rejected, and a bookkeeping PR is merged; results recorded in STATE.

## Scope

Touched: `scripts/devloop/integrate.sh`, `scripts/devloop/protect.sh`,
`scripts/devloop/common.sh`, `.devloop.conf`, `.devloop.conf.example`,
`.github/CODEOWNERS`, `dist/devloop-skill/refresh.sh`, `dist/devloop-skill/SKILL.md`,
`.agents/skills/dev-cycle/SKILL.md`, `AGENTS.md`, `README.md`,
`design/04-gates-and-review.md`, `tests/run.sh`, `docs/tasks/task-006.md`, and
the refreshed bundle.

Out of scope: AC-as-code, mutation checks and extra linters (task-007).

## Verification plan

1. `bash tests/run.sh`.
2. `bash scripts/devloop/gate.sh`.
3. `integrate.sh --task task-006 --pr` (dogfood).
4. `bash scripts/devloop/protect.sh`, then verify in a scratch clone that a
   direct push to `main` is rejected.
5. Open and merge a `state/<sha>` PR for the bookkeeping update.

## Risks

- `enforce_admins: true` blocks direct pushes, including the bookkeeping
  exception; STATE/LESSONS now go through a small PR.
- `REQUIRED_APPROVALS` must stay 0 with a single GitHub account (no self-review
  on GitHub); the file-based review remains the process gate.
- The first `--pr` run is the real validation; the local suite cannot execute
  GitHub.
- Protection is applied only after this task is merged (bootstrap order).
