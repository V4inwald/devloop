---
name: task-authoring
description: Write a task file with testable acceptance criteria, scope, and size before implementation starts. Use when planning work in a devloop repository or when a task is too vague to verify.
whenToUse: Before creating a branch, when splitting an oversized task, or when acceptance criteria cannot be checked by a command.
---

# task-authoring — a task is a contract, not a wish

The task file is what the reviewer measures against and what the next agent reads six weeks
from now. If it is vague, the review becomes opinion and the work becomes unbounded.

## Definition of ready

A task may start only when all of these are true:

1. **Outcome** — one sentence describing observable behaviour after the change.
2. **Acceptance criteria** — each one checkable by a command or an explicit manual step.
3. **Scope** — files/directories expected to change, and an explicit out-of-scope list.
4. **Size** — estimated diff lines. Above `MAX_DIFF_LINES` (default 400) → split now.
5. **Risks** — what could break, and what evidence would catch it.
6. **Dependencies** — other tasks or external state required first.

If any is missing, the correct action is to ask, not to guess.

## Format

`docs/tasks/<id>.md`:

```markdown
---
id: task-001
status: ready        # draft | ready | in_progress | review | done | blocked
branch: task/001-short-slug
created: YYYY-MM-DD
owner: <agent or human>
---

# <short title>

## Outcome

<One sentence, observable.>

## Acceptance criteria

- [ ] AC1: `node --test test/parser.test.js` passes, including the new escaped-quote case.
- [ ] AC2: malformed input returns exit code 2 with a message naming the offending line.
- [ ] AC3: no public API signature changes.

## Scope

Touched: `src/parser.js`, `test/parser.test.js`
Out of scope: CLI flags, docs site, dependency upgrades.

## Verification plan

1. `bash scripts/devloop/gate.sh` — unit + lint.
2. Manual: pipe `a"b` through the CLI, expect exit 0 and the escaped form.

## Risks

- Parser is used by the importer; if the signature changes, the importer breaks. Mitigation:
  AC3 plus the importer's test suite.

## Notes / decisions

- Append dated notes here during implementation. Do not rewrite the criteria after the fact;
  if they were wrong, say so and add a revision note.
```

## Writing acceptance criteria

| Bad | Why | Better |
|---|---|---|
| "Handle edge cases" | not checkable | "input `""` returns `[]`, not an error" |
| "Tests pass" | the gate already means that | "new test fails on the parent commit and passes here" |
| "Improve performance" | no threshold | "10k-line fixture parses in < 2 s on CI" |
| "Refactor parser" | no observable behaviour | "same outputs on the 40-case corpus; no API change" |

One criterion, one check. If it cannot be automated, state the manual step and who performs it.

## Sizing and splitting

Split by **behaviour**, not by file:

- mechanical change (rename, move) separate from behavioural change;
- test infrastructure separate from the feature it enables;
- dependency upgrade separate from the code that needs it;
- migration separate from the code that writes the new format.

A split task keeps its own acceptance criteria and its own review. Two small reviewed changes
beat one large unreviewable one.

## Status transitions

`draft → ready → in_progress → review → done`, plus `blocked` with a reason and an owner.
Only the Lead moves `review → done`, and only after `integrate.sh` succeeded.

## Anti-patterns

- A task file written after the code, to satisfy the process.
- Acceptance criteria copied from the implementation ("the function returns X because it does").
- Hidden scope ("while I was there, I also…") — that belongs to another task.
- A task with no out-of-scope line; every task has something tempting nearby.
