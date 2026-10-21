---
id: task-010
status: done
branch: task/010-doctor-task-bookkeeping
created: 2026-10-21
owner: lead
implementer: lead
---

# Reconnaître le bookkeeping des fichiers de tâche dans doctor

## Outcome

`doctor.sh` accepts a bookkeeping commit that updates a task file's status or acceptance
checkboxes alongside `STATE.md`/`LESSONS.md`, as decided by ADR 0002, instead of demanding a
gate and a review for the bookkeeping commit itself.

## Acceptance criteria

- [x] AC1: the bookkeeping detection accepts `docs/tasks/*.md` in addition to `docs/STATE.md` and `docs/LESSONS.md`, with a comment pointing at ADR 0002.
- [x] AC2: the bookkeeping-doctor test changes STATE and a task file in the same commit; it fails on the parent and passes on this branch.
- [x] AC3: `bash tests/run.sh` and `gate.sh` pass; `doctor` reports 0 error on the real state merge (39fe4f7).
- [x] AC4: the state PR closes task-010 under ADR 0002 and doctor still passes.

## Scope

Touched: `scripts/devloop/doctor.sh`, `tests/run.sh`, `docs/tasks/task-010.md`, refreshed bundle,
`docs/STATE.md`/`docs/LESSONS.md` in the state PR.

## Verification plan

1. `bash tests/run.sh`.
2. `bash scripts/devloop/gate.sh`.
3. `bash scripts/devloop/doctor.sh` on `main` (39fe4f7) -> 0 error.
4. State PR under protection -> doctor 0 error on the merge.

## Risks

- Any change under `docs/tasks/` is now accepted as bookkeeping; the process (ADR 0002) forbids
  editing acceptance text, but the doctor cannot enforce that distinction. The review of the
  state change covers it.

## Notes / decisions

- 2026-10-21: merged as PR #9; the state PR closes it under ADR 0002. The new doctor accepts the
  state merge's STATE + task-file bookkeeping (0 errors).
