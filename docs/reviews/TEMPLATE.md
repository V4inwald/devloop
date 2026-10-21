---
task: task-NNN
sha: <full 40-char sha of the reviewed HEAD>
verdict: revise
blockers: 1
reviewer: <agent name or human>
date: YYYY-MM-DD
---

# Review — task-NNN round N

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | <which criterion, which command, which result> |
| Tests | <test file:line; does it fail without the change?> |
| Test integrity | <assertions removed/added; skipped tests> |
| Correctness | <reasoning or command> |
| Errors | <failure path inspected> |
| Security | <injection, secrets, authz — or "not applicable: no input boundary"> |
| Compatibility | <API/DB/format impact> |
| Scope | <files outside the task> |
| Readability | <only if it affects maintenance> |
| Docs | <what future agents need and where it is recorded> |

## Blockers

1. `<file>:<line>` — <problem>. Required fix: <smallest acceptable change>.

## Findings (non-blocking)

- `<file>:<line>` — <observation>. No behavioural impact.

## Verdict rationale

<2–4 sentences: why this verdict, what would change it.>
