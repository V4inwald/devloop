---
id: task-001
status: review
branch: task/001-artifacts
created: 2026-10-21
owner: lead
implementer: lead
---

# Artefacts partagés entre worktrees et gate honnête

## Outcome

Running the gate never dirties the tree, the evidence store is shared by every
worktree of a repository, and a dirty run can never be quoted as a pass.

## Acceptance criteria

- [x] AC1: `bash tests/run.sh` passes, including the new artifact and dirty-gate assertions.
- [x] AC2: on a clean tree, two consecutive gate runs leave `git status --porcelain` empty and record `dirty: false`.
- [x] AC3: the artifact store lives under `$(git rev-parse --git-common-dir)/devloop` and is visible from a linked worktree.
- [x] AC4: a gate run on a dirty tree exits 3 and never prints `PASSED`.
- [x] AC5: `doctor.sh` reports the merge commit as gated when a merge gate exists, and still accepts legacy integration records. Tested with synthetic merge-gate evidence and a copied legacy store; `integrate.sh` will write `merge_gate` in task-002.

## Scope

Touched: `scripts/devloop/common.sh`, `scripts/devloop/gate.sh`,
`scripts/devloop/doctor.sh`, `.github/workflows/ci.yml`, `tests/run.sh`,
`docs/tasks/task-001.md`, `docs/reviews/task-001-r1.md`.

Out of scope: `integrate.sh` (task-002), install, documentation.

## Verification plan

1. `bash scripts/devloop/gate.sh`
2. `bash tests/run.sh`
3. Manual: two gate runs, then `git status --porcelain` must be empty.

## Risks

- Existing installations keep artifacts in `.devloop/`; doctor must tolerate the
  old path and the old integration records -> covered by AC5.
- `git rev-parse --path-format` needs git >= 2.31; a fallback keeps older git working.

## Notes / decisions

- 2026-10-21 (round 1 review): four blockers found and fixed.
  1. doctor misreported `$ROOT/.git/devloop` as "inside the worktree"; the
     shared-store arm now checks `$GIT_COMMON_DIR/*` first.
  2. doctor ignored legacy evidence; it now falls back read-only to
     `$ROOT/.devloop/artifacts` and warns when it does.
  3. the gate ran `CHECK_*` through `bash -c`, breaking the documented `eval`
     contract (shell functions in `.devloop.conf` stopped working); restored
     `( eval "$cmd" )`.
  4. the CI upload still pointed at `.devloop/artifacts`; the workflow now sets
     `DEVLOOP_ARTIFACTS` to `${{ runner.temp }}/devloop` and uploads that path.
- Scope kept to the task: the `merge_base`/`diff_lines` helpers, provenance
  metadata and the contract-drift warning were removed from this change and
  belong to task-002 (integration) and task-004 (docs).
- Deferred deliberately: `integrate.sh` starts writing `merge_gate` in
  task-002; doctor already consumes it.
- 2026-10-21 (round 2): two independent verdicts on the same SHA.
  `task-001-r2.md` = revise, `task-001-r3.md` = approve. The stricter finding
  wins: `runner.temp` is not available in `jobs.<job_id>.env`, so
  `DEVLOOP_ARTIFACTS` moved to the gate step. r3 did not catch that context
  bug, which is why the CI fix is taken anyway.
- 2026-10-21 (size accounting): review verdicts are the output of the review,
  not part of the change. `diff_lines` now excludes `docs/reviews/`; the
  substantive diff is 319 lines, under `MAX_DIFF_LINES=400`, and a test pins
  the exclusion.
