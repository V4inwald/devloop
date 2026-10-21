---
id: task-009
status: done
branch: task/009-final-hardening
created: 2026-10-21
owner: lead
implementer: lead
---

# Durcissement final du guard, CI dédupliquée et clôture des tâches

## Outcome

`main-guard` only acts on PR-mode repositories, reports API failures instead of aborting, and
checks the PR base branch; a PR no longer runs `gate` twice; the task files close under a
documented bookkeeping rule; the bundle is complete and drift-tested.

## Acceptance criteria

- [x] AC1: `main-guard` skips when `REQUIRE_PR` is not true, creates the issue even if `gh pr view` fails, and rejects a PR merged into a non-default base.
- [x] AC2: `ci.yml` no longer triggers on task branches; the pull request run is the only task-branch check (documented for local mode).
- [x] AC3: ADR 0002 defines the task-status/bookkeeping rule; AGENTS §2 reflects it; task-001..008 are `done` with their final ACs checked.
- [x] AC4: `.gitignore` covers `.gh/`, `id_ecdsa`, `id_dsa`; the guard/CI/bundle tests pass.
- [x] AC5: `bash tests/run.sh` and `gate.sh` pass; the bundle is refreshed.

## Scope

Touched: `.github/workflows/main-guard.yml`, `.github/workflows/ci.yml`, `.gitignore`,
`AGENTS.md`, `docs/adr/0002-task-status-and-bookkeeping.md`, `docs/tasks/*.md`,
`tests/run.sh`, `docs/tasks/task-009.md`, refreshed bundle.

Out of scope: AC-as-code and `prove-red.sh` (documented as the next quality step), history
rewrite, changing other projects' visibility.

## Verification plan

1. `bash tests/run.sh` (>= 119 assertions).
2. `bash scripts/devloop/gate.sh`.
3. PR merge under protection; `main-guard` and `ci` green on the merge.
4. State PR closes task-009 under ADR 0002.

## Risks

- The guard still cannot prevent a direct push; branch protection is the barrier. A direct push
  that edits the workflow/conf can blind the detection (accepted residual).
- A local-mode project installing the guard is protected by the runtime skip, but the checkout
  step still runs; the workflow comment explains it.
- Task files are edited after integration by design; only status/checkboxes, never acceptance.

## Notes / decisions

- 2026-10-21: merged as PR #7; `main-guard` and `ci` are green on the merge. Closed under
  ADR 0002 by the follow-up state PR.
