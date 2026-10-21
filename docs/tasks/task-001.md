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

- Round 1 (revise): four blockers — doctor's store arm, the legacy fallback,
  the `bash -c` regression against the documented `eval`, and the CI upload
  path. All are fixed and pinned by tests. Round 2 split (r2 revise / r3
  approve) confirmed that the `runner` context is step-scoped; the env moved
  to the gate step.
- Scope kept to the task; the merge_base/diff_lines provenance and the
  contract warning belong to task-002/task-004. `merge_gate` is consumed by
  doctor and produced by task-002.
- Size: `diff_lines` excludes `docs/reviews/` because verdicts are review
  output, not the change; a test pins it.
