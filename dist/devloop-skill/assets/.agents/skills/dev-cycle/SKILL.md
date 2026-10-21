---
name: dev-cycle
description: Run one repository task through the devloop pipeline — task file, branch, commits, gate, independent review, integration, memory update. Use for any feature, fix, refactor, or test change in a repository that contains .devloop.conf and scripts/devloop/.
whenToUse: The user asks for a code change in a devloop-enabled repository, or asks to continue/close a task whose file is in docs/tasks/.
---

# dev-cycle — one task, end to end

You are executing the repository's development loop. The loop is enforced by scripts, not by
good intentions. Read `AGENTS.md` first; this skill is the procedure behind it.

## Roles

| Role | Who | May write |
|---|---|---|
| Lead | the agent talking to the human | task file, STATE.md, routing |
| Implementer | one context per task | code, tests, task file notes |
| Reviewer | a **different** context | the review file only |
| Integrator | Lead | merge via `integrate.sh` |

If you are alone, you are Lead + Implementer. The reviewer must still be a separate context
(subagent) or a human. Self-review is the fallback of last resort: `reviewer: self` and explicit
human approval before integration.

## Step 0 — session bootstrap (once per session)

1. Read `docs/STATE.md`.
2. Run `bash scripts/devloop/doctor.sh`. Fix ERRORs before starting anything new.
3. Read the task file you will work on, if it exists.

## Step 1 — task file (definition of ready)

Create or complete `docs/tasks/<id>.md` (format: skill `task-authoring`). It must contain:
outcome, acceptance criteria that a command can check, files you expect to touch, out of scope,
and a size estimate. If the estimate exceeds `MAX_DIFF_LINES`, split the task now, not later.
Do not start implementing before this file exists.

## Step 2 — branch

```bash
git switch -c task/<id>-<slug>
```

One task per branch. Never reuse a branch after integration.

## Step 3 — implement

- Work in small commits that each keep the repository coherent.
- Write or update tests in the same commit as the behaviour they cover.
- Never weaken an existing test to make something pass. If a test must change, say why in the
  task file before changing it.
- Commit messages: Conventional Commits, imperative, ≤72 characters.
- Run `bash scripts/devloop/gate.sh` before every commit that claims to work. It is cheap and
  it is the only thing that counts.

If the change requires touching a protected area (auth, payments, migrations, CI, secrets),
stop and escalate to the human before writing code.

## Step 4 — gate

```bash
bash scripts/devloop/gate.sh --task <id>
```

- Exit 0 and `ok=true`, `dirty=false` in `.devloop/artifacts/gate/<sha>/result.json` → continue.
- Exit 1 → read the failing log named in the output, fix, commit, re-run. Do not lower the bar
  (no skipped tests, no `|| true`, no loosened assertions).
- The tree must be clean when the passing gate is recorded. Uncommitted work does not count.

## Step 5 — review

1. Build the packet: `bash scripts/devloop/packet.sh` → prints the packet path.
2. Hand the packet to a **separate reviewer context** (subagent, teammate, or human) with the
   skill `code-review`. Give it the packet path and the task file path; nothing else.
3. The reviewer writes `docs/reviews/<task>-r<N>.md` with frontmatter `sha:` = HEAD of the
   reviewed state, `verdict:`, `blockers:`.
4. Verdict handling:
   - `approve` + `blockers: 0` → commit the review file:
     `git add docs/reviews && git commit -m "docs(reviews): approve <task>"`
     then re-run the gate, because HEAD moved.
   - `revise` → return the blockers to the implementer as a numbered list. Fix, commit, gate,
     re-review as round N+1. Maximum 2 rounds; then escalate.
   - `reject` → stop and escalate with the reviewer's reasons.
5. Never edit a review file after it is committed. A new verdict is a new file.

## Step 6 — integrate

```bash
bash scripts/devloop/integrate.sh --task <id> --dry-run   # checks first
bash scripts/devloop/integrate.sh --task <id>
```

It refuses without a passing clean gate for HEAD and an approving review covering HEAD. If it
refuses, fix the cause; do not bypass it with a manual merge. The merge message and the audit
record are generated.

## Step 7 — record memory

After the merge:

1. Update `docs/STATE.md`: `last_verified_sha`, current focus, next actions, known issues.
2. Append a line to `docs/LESSONS.md` if something was learned.
3. Write an ADR (`docs/adr/`) if a decision will constrain future work. ADRs are immutable once
   accepted; supersede with a new one.
4. Mark the task file `done`.

## Failure handling

| Symptom | Action |
|---|---|
| gate fails for a flaky test | Re-run once. If flaky, record it in STATE.md as a known issue and fix it in its own task; do not retry until green. |
| review blocked because diff too large | Split the task and restart at Step 1. |
| merge conflict in `integrate.sh` | Abort the merge, rebase the task branch on `main`, re-run gate, re-run safety check, retry. The review stays valid only if the code is unchanged. |
| review file exists but integrate says stale | A commit after review changed code. Re-review the new HEAD. |
| `doctor.sh` reports stale STATE | Re-verify before trusting any state claim. |

## Parallel work

- One worktree per task: `git worktree add ../<repo>-<task> -b task/<id>-<slug>`.
- One writer per worktree. Two agents editing one worktree is a merge conflict with extra steps.
- Integrate serially. A second integration waits until `main` is updated and the branch rebased.
- Never let two tasks touch the same file; if unavoidable, sequence them with a dependency note.

## Stop conditions

Escalate instead of looping when: two review rounds failed, the gate cannot run (missing
service/credential), the fix needs a protected area, or the task turns out bigger than
`MAX_DIFF_LINES` after splitting once.

## Never

- Never claim a task is done without a gate artifact and a review file for HEAD.
- Never use `--no-verify` to get past a hook.
- Never push to `main` directly.
- Never mark your own work approved when the policy requires an independent reviewer.
