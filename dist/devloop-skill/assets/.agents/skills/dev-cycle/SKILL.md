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
| Lead | the agent talking to the human | task file, `STATE.md`, packet, routing |
| Implementer | one context per task, `cwd` = its worktree | code, tests, task notes |
| Reviewer | a **different** context | the review file only |
| Integrator | Lead, serialized | merge via `integrate.sh`, `STATE.md` |

If you are alone, you are Lead + Implementer. The reviewer must still be a separate context
(subagent) or a human. Self-review is the fallback of last resort: `reviewer: self` plus
`approved_by:` and explicit human approval before integration.

## Step 0 — session bootstrap (once per session)

1. Read `docs/STATE.md`.
2. Run `bash scripts/devloop/doctor.sh`. Fix ERRORs before starting anything new.
3. Read the task file you will work on, if it exists.
4. Check `git status --short`; a dirty tree is not evidence.

## Step 1 — task file (definition of ready)

Create or complete `docs/tasks/<id>.md` (format: skill `task-authoring`). It must contain:

- frontmatter `id`, `status`, `branch`, `implementer`;
- outcome, acceptance criteria that a command can check, files you expect to touch,
  out of scope, and a size estimate.

If the estimate exceeds `MAX_DIFF_LINES`, split the task now, not later. Commit the task file:
`integrate.sh` reads it from HEAD and refuses a missing or mismatched contract.

## Step 2 — branch

```bash
git switch -c task/<id>-<slug>
# parallel work: git worktree add ../<repo>-<id> -b task/<id>-<slug>
```

One task per branch, one writer per worktree. Never reuse a branch after integration.

## Step 3 — implement

- Work in small commits that each keep the repository coherent.
- Write or update tests in the same commit as the behaviour they cover.
- Never weaken an existing test to make something pass. If a test must change, say why in the
  task file before changing it.
- Commit messages: Conventional Commits, imperative, ≤72 characters.
- Run `bash scripts/devloop/gate.sh` before every commit that claims to work.

If the change requires touching a protected area (auth, payments, migrations, CI, secrets),
stop and escalate to the human before writing code.

## Step 4 — gate

```bash
bash scripts/devloop/gate.sh --task <id>
```

- Evidence is written to `$(git rev-parse --git-common-dir)/devloop/gate/<sha>/`, shared by
  all worktrees and never inside the worktree.
- exit 0 with `ok=true`, `dirty=false` → continue.
- exit 1 → read the failing log named in the output, fix, commit, re-run.
- exit 3 → checks passed but the tree was dirty (`UNVERIFIED`): commit and re-run. Never
  integrate a dirty result.
- exit 2 → configuration/usage error (no `CHECK_*`, unknown argument).

Do not lower the bar: no skipped tests, no `|| true`, no loosened assertions.

## Step 5 — review

1. Build the packet: `bash scripts/devloop/packet.sh` → `.git/devloop/review/<sha>-packet.md`.
2. Hand the packet and the task file to a **separate reviewer context** with the skill
   `code-review`. Give it those two paths; nothing else.
3. The reviewer writes `docs/reviews/<task>-r<N>.md` with frontmatter `task:`, `sha:` (full
   HEAD reviewed), `verdict:`, `blockers:`, `reviewer:`, `contract:`.
4. Verdict handling:
   - `approve` + `blockers: 0` → commit the review file (the reviewer must not commit it), then
     **re-run the gate**, because HEAD moved.
   - `revise` → fix the blockers, commit, gate, re-review as round N+1. Maximum 2 rounds; then
     escalate.
   - `reject` → stop and escalate with the reviewer's reasons.
5. Never edit a review file after it is committed, and never commit a draft before the reviewer
   reports its final verdict. A new verdict is a new file.

The review must be **added after** the reviewed commit: `integrate.sh` refuses a review that
existed at the reviewed SHA, and pins the review blob in the integration record.

## Step 6 — integrate

```bash
bash scripts/devloop/integrate.sh --task <id> --dry-run   # checks first
bash scripts/devloop/integrate.sh --task <id> [--allow-oversized] [--push]
```

It refuses without a committed task contract, a clean passing gate for HEAD, and an approving
review for the task that was added after the reviewed SHA. If the branch touches contract paths
(`.devloop.conf`, `scripts/devloop`, `.githooks`, workflows, `AGENTS.md`), the review must say
`contract: approved`.

The merge is built in a detached worktree, the **merge result is gated**, and `main` only moves
afterwards. A failing merge gate leaves `main` untouched. Integrations are serialized by a lock.
`--push` uses `ALLOW_MAIN_PUSH=1` in the environment only; `.devloop.conf` is ignored by the
pre-push hook. If it refuses, fix the cause; a manual merge is out of the contract.

## Step 7 — record memory

After the merge:

1. Update `docs/STATE.md`: `last_verified_sha` (the merge commit), current focus, next actions.
2. Append a line to `docs/LESSONS.md` if something was learned.
3. Write an ADR (`docs/adr/`) if a decision will constrain future work.
4. Mark the task file `done` (see the transition note in the task-authoring skill).

## Failure handling

| Symptom | Action |
|---|---|
| gate fails for a flaky test | Re-run once. If flaky, record it in STATE.md as a known issue and fix it in its own task; do not retry until green. |
| review blocked because diff too large | Split the task and restart at Step 1. |
| merge conflict or failing merge gate | `integrate.sh` leaves `main` untouched. Rebase the task branch on `main`, re-run the gate, re-run the review if the code changed, retry. |
| review file exists but integrate says stale | A commit after review changed code. Re-review the new HEAD. |
| `doctor.sh` reports stale STATE | Re-verify before trusting any state claim. |
| another integration holds the lock | Wait; integrations are serialized on purpose. |

## Parallel work

- One worktree per task: `git worktree add ../<repo>-<task> -b task/<id>-<slug>`.
- One writer per worktree. Two agents editing one worktree is a merge conflict with extra steps.
- The evidence store is shared by worktrees (`<git-common-dir>/devloop`); a gate in one worktree
  is visible to the integrator in another.
- Integrate serially: one lock, one integrator. A second integration waits for `main` to move and
  the branch to be rebased.
- Never let two tasks touch the same file; if unavoidable, sequence them with a dependency note.
- Limit to 2–3 tasks in flight; beyond that the coordination costs more than the parallel gain.

## Stop conditions

Escalate instead of looping when: two review rounds failed, the gate cannot run (missing
service/credential), the fix needs a protected area, or the task turns out bigger than
`MAX_DIFF_LINES` after splitting once.

## Never

- Never claim a task is done without a gate artifact and a review file for HEAD.
- Never use `--no-verify` to get past a hook.
- Never push to `main` directly; the only deliberate override is `ALLOW_MAIN_PUSH=1`.
- Never mark your own work approved when the policy requires an independent reviewer.
