---
id: task-002
status: review
branch: task/002-integrate
created: 2026-10-21
owner: lead
implementer: lead
---

# Intégration durcie : contrat, revue immuable, merge testé, worktrees

## Outcome

`integrate.sh` merges only a task whose committed contract, approval and code
agree, and whose merge result has passed the gate itself; two worktrees can
integrate without racing or checking out `main` twice.

## Acceptance criteria

- [x] AC1: integrate refuses a missing or mismatched task file, a review for another task, a self-review without `approved_by`, and a review modified after the reviewed SHA.
- [x] AC2: a review must be added after the reviewed SHA and its blob is recorded in the integration record and the merge trailers.
- [x] AC3: contract paths changed by the branch require `contract: approved` in the review.
- [x] AC4: the merge result is gated in a detached worktree before `main` moves; a failing merge gate leaves `main` untouched.
- [x] AC5: integrate works from a linked task worktree when `main` is checked out elsewhere, serialized by a lock.
- [x] AC6: doctor accepts a bookkeeping commit whose parent is an integration merge; `bash tests/run.sh` passes (63 assertions).

## Scope

Touched: `scripts/devloop/integrate.sh`, `scripts/devloop/common.sh`,
`scripts/devloop/doctor.sh`, `tests/run.sh`, `docs/tasks/task-002.md`.

Out of scope: install, CI workflow, `policy.sh`, pre-push, documentation
(task-003/task-004).

## Verification plan

1. `bash scripts/devloop/gate.sh`
2. `bash tests/run.sh`
3. Manual: `integrate.sh` from a worktree while `main` is checked out in another.

## Risks

- Existing integration records lack `review_blob`/`merge_gate`; doctor keeps the
  legacy path and the legacy artifact store.
- The review matcher is duplicated in doctor and integrate; a divergence can
  make them disagree (`review_covers` vs the inline scan). Covered by tests but
  not deduplicated yet.
- `--push` is implemented but not exercised by the suite (no remote in tests).

## Notes / decisions

- `fm` now returns an empty value for a missing key instead of propagating a
  failed pipeline under `set -e`; a review without the optional `contract` field
  no longer aborts integration.
- The merge is created in a detached `git worktree`, gated there, then `main` is
  fast-forwarded (or updated by ref when not checked out). This closes the
  semantic-merge hole and makes the bookkeeping commit doctor-clean.
- Review files are pinned by `Reviewed-by:` + `Reviewed-blob:` trailers and by
  `review_blob` in the integration record; only `A` additions under
  `docs/reviews/` are tolerated after the reviewed SHA.
