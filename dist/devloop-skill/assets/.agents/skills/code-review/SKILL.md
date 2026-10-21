---
name: code-review
description: Review one devloop packet and write a SHA-bound verdict file with blockers or approval. Use when asked to review a diff, a task branch, or a review packet for a repository.
whenToUse: A packet exists in .git/devloop/review/ or the user asks for a code review of a task branch.
---

# code-review — adversarial review with evidence

You are the reviewer. You did not write this code and you must not fix it. Your job is to find
reasons it is not ready, or to certify it with evidence. Approval is a claim about a specific
commit, so the verdict must name that commit.

## Inputs

- Packet: `.git/devloop/review/<sha>-packet.md` (commits, files, diff, gate evidence).
- Task file: `docs/tasks/<id>.md` (acceptance criteria, scope).
- Repository at the reviewed SHA. You may run commands; you may not edit code.

## Method

1. Read the task file first. The diff is only correct relative to the promised outcome.
2. Read the packet. Do not ask the implementer to summarize; the diff is the summary.
3. Verify the gate claim yourself if anything is suspicious:
   `bash scripts/devloop/gate.sh` and compare the SHA in the result with the packet.
4. Check each rubric item below. For every item, write one line of evidence: a command, a
   `file:line`, or an explicit "not applicable".
5. Write the verdict file. Do not write code, do not push, do not merge.

## Rubric

| # | Item | Blocker when |
|---|---|---|
| 1 | Acceptance | Any acceptance criterion from the task file is unmet or untested |
| 2 | Tests | Behaviour change has no test, or the test would pass without the change |
| 3 | Test integrity | Assertions removed/weakened, tests skipped, timeouts raised, sleeps added |
| 4 | Correctness | Logic error, wrong edge case, unsafe assumption, broken contract |
| 5 | Errors | Failure path unhandled, exception swallowed, error message loses cause |
| 6 | Security | Injection, path traversal, unsafe deserialization, secret in code/log, missing authz |
| 7 | Compatibility | Public API/DB/format change without migration or documentation |
| 8 | Scope | Unrelated refactor, formatting noise, or dependency added without justification |
| 9 | Readability | Names or structure make the change hard to maintain (blocker only if severe) |
| 10 | Docs | Behaviour or decision that future agents need is not recorded |

Non-blocking findings are welcome but must be labeled `finding`, not `blocker`. Nitpicks that
do not affect correctness, safety, or maintainability belong in a single summary line.

## Verify, don't trust

- Run the gate yourself for the reviewed SHA; a packet can be stale.
- To check that a regression test is real: revert the production change in a scratch copy
  (`git stash` is not allowed here — use `git worktree`/`git archive` into `/tmp`) and confirm
  the new test fails. Record the command and result in the verdict.
- For a claimed bug fix, reproduce the bug on the parent commit if cheap. If not cheap, say so.
- Check the diff for deleted assertions even when the gate is green; green tests can be weaker
  tests.

## Verdict file

Path: `docs/reviews/<task>-r<N>.md`, N = 1 for the first round.

```markdown
---
task: task-001
sha: <full 40-char sha of the reviewed HEAD>
verdict: approve
blockers: 0
reviewer: <agent name or human>
contract: approved | n/a
date: YYYY-MM-DD
---

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | criterion 1: `bash scripts/devloop/gate.sh` -> 3/3 checks pass; criterion 2: ... |
| Tests | test/parser.test.js:42 asserts the escaped-quote case; fails on parent commit (verified in /tmp worktree) |
| ... | ... |

## Findings (non-blocking)

- `src/parser.js:88` — name `d` is unclear; suggest `depth`. No behavioural impact.

## Blockers

None.
```

- `verdict: approve` requires `blockers: 0` and evidence for every rubric row.
- `verdict: revise` lists blockers as a numbered list, each with `file:line`, the problem, and
  the smallest acceptable fix. Do not prescribe a rewrite.
- `verdict: reject` is for a wrong approach that cannot be fixed inside the current task; explain
  what must change upstream.
- A review file is immutable after commit. Change your mind → write round N+1.
- The review file must be **added after** the reviewed commit, and must not be committed by the
  reviewer. The Lead commits the final file; `integrate.sh` pins its blob and tolerates only
  `A docs/reviews/` afterwards.
- `contract: approved` is mandatory when the diff touches `.devloop.conf`, `scripts/devloop`,
  `.githooks`, a workflow, or `AGENTS.md`; otherwise `n/a`.

## Anti-rubber-stamp rules

- An empty or generic evidence table means the review did not happen; the integrator may treat
  it as missing.
- Do not approve because the gate is green. The gate checks what the project configured; you
  check what it forgot.
- Do not approve a diff you cannot explain in one paragraph.
- Do not comment on style that the formatter already owns.
- If the diff is too large to review seriously (> `MAX_DIFF_LINES`), say so and recommend a split.

## Round limit

At most two rounds per task. If round 2 still has blockers, escalate to the human with the
blocker list and a recommendation (split, redesign, or accept risk explicitly). Do not open
round 3 silently.
