---
id: task-001
status: in_progress
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

- [ ] AC1: `bash tests/run.sh` passes, including the new artifact and dirty-gate assertions.
- [ ] AC2: on a clean tree, two consecutive gate runs leave `git status --porcelain` empty and record `dirty: false`.
- [ ] AC3: the artifact store lives under `$(git rev-parse --git-common-dir)/devloop` and is visible from a linked worktree.
- [ ] AC4: a gate run on a dirty tree exits 3 and never prints `PASSED`.
- [ ] AC5: `doctor.sh` reports the merge commit as gated when a merge gate exists, and still accepts legacy integration records.

## Scope

Touched: `scripts/devloop/common.sh`, `scripts/devloop/gate.sh`,
`scripts/devloop/doctor.sh`, `tests/run.sh`, `docs/tasks/task-001.md`.

Out of scope: `integrate.sh`, install, CI, documentation.

## Verification plan

1. `bash scripts/devloop/gate.sh`
2. `bash tests/run.sh`
3. Manual: two gate runs, then `git status --porcelain` must be empty.

## Risks

- Existing installations keep artifacts in `.devloop/`; doctor must tolerate the
  old path and the old integration records -> covered by AC5.
- `git rev-parse --path-format` needs git >= 2.31; a fallback keeps older git working.
