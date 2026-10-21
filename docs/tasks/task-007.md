---
id: task-007
status: done
branch: task/007-main-guard
created: 2026-10-21
owner: lead
implementer: lead
---

# Détecter les pushes directs quand la protection serveur est indisponible

## Outcome

On a private GitHub Free repository, a push to `main` that is not a verified
pull-request merge is detected within seconds, reported in an issue, and marked
red — while the documentation states plainly that this is detection, not
prevention, and how to get real protection.

## Acceptance criteria

- [x] AC1: `.github/workflows/main-guard.yml` runs on `push` to `main`, verifies the head is the merge commit of a merged PR, and otherwise opens an issue and fails.
- [x] AC2: the installer ships both workflows (`devloop-ci.yml` and `devloop-main-guard.yml`) without clobbering an existing `ci.yml`.
- [x] AC3: `protect.sh` maps the private-Free 403 to an actionable message (keep private + main-guard, public repo, or GitHub Pro/Team).
- [x] AC4: README, SKILL, AGENTS and design/04 state that branch protection depends on the plan; `main-guard` is detection, not prevention.
- [x] AC5: `bash tests/run.sh` and `gate.sh` pass; the bundle is refreshed and drift-tested.

## Scope

Touched: `.github/workflows/main-guard.yml`, `dist/devloop-skill/install.sh`,
`scripts/devloop/protect.sh`, `README.md`, `dist/devloop-skill/SKILL.md`,
`AGENTS.md`, `design/04-gates-and-review.md`, `tests/run.sh`,
`docs/tasks/task-007.md`, and the refreshed bundle.

Out of scope: making the repository public (a separate decision and a separate
task), AC-as-code and mutation checks (task-008).

## Verification plan

1. `bash tests/run.sh`.
2. `bash scripts/devloop/gate.sh`.
3. Static read of the guard workflow; the real detection runs only on a GitHub
   direct push, which we will not perform on the protected/real history.

## Risks

- Detection happens **after** the push: the commit is already on `main`. The
  guard opens an issue and fails, it does not revert.
- If the repository goes public or the plan is upgraded, `protect.sh` becomes
  the real prevention and the guard becomes a belt-and-suspenders check.
- The guard trusts GitHub's merge-commit subject + the PR's `mergeCommit.oid`;
  a squash/rebase merge is flagged (by design: the loop uses merge commits).
