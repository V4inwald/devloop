---
name: devloop
description: Install and run a SHA-bound development loop in a repository — task file, branch, commits, gate, independent review, integration. Use when a change must be tested, reviewed and merged with evidence rather than trusting an agent's summary. Also use to set up this workflow in a project that does not have it yet.
whenToUse: The user asks for a code change in a devloop-enabled repository, asks to install or try the devloop workflow, asks for a revue/tests/commits propres, or asks to "use the skill devloop" (French or English).
---

# devloop — callable procedure

This skill gives you the full loop in any repository. The installer and its assets
sit next to this file (`install.sh` + `assets/`). Once installed, the enforcement
lives in the target repository, not in the skill.

The base directory of this skill is shown in your skill header. Call it `SKILL_DIR`.

## Step 0 — inspect before acting

```bash
git rev-parse --show-toplevel 2>/dev/null || echo "NO REPO"
ls .devloop.conf scripts/devloop/gate.sh AGENTS.md 2>/dev/null
git status --short
```

| State | Action |
|---|---|
| no git repository | ask the user whether to `git init`; do not create one silently |
| repo without `.devloop.conf` | install, Step 1 |
| repo with `.devloop.conf` | skip to Step 2 |

If the user only asked a question or a quick look, do not run the pipeline.

## Step 1 — install (once per repository)

```bash
bash "<SKILL_DIR>/install.sh" --dry-run   # show what would change
bash "<SKILL_DIR>/install.sh"
```

The installer is **non-destructive**:

- it refuses to overwrite a kit file (exit 4) and lists the conflicts;
- `--force` overwrites only those files and keeps a backup under
  `<git-common-dir>/devloop/backup-<utc>`;
- it never overwrites `.devloop.conf`, `docs/STATE.md`, `docs/LESSONS.md` or
  `AGENTS.md`, and it never deletes hooks, scripts or workflows it did not create;
- it installs the CI workflow as `.github/workflows/devloop-ci.yml`, so an
  existing `ci.yml` is preserved;
- a fresh install writes a neutral `docs/STATE.md` (`last_verified_sha: unset`)
  and a template `docs/LESSONS.md`.

Then adapt `.devloop.conf` to the real project. Infer before asking:

- `package.json` scripts (`test`, `lint`, `build`);
- `Makefile` targets; `pyproject.toml` / `Cargo.toml` / `go test`;
- existing CI workflow commands.

Rules for the config:

- at least one `CHECK_*` must be non-empty, otherwise the gate errors;
- never put `true` or a command that cannot fail;
- prefer a fast test command for `CHECK_TEST`; put the slow suite in
  `CHECK_INTEGRATION` and run it before integration, not on every commit;
- `CHECK_*` are evaluated with `eval` in the repository shell, so functions
  declared in `.devloop.conf` work; treat the file as code.

Show the resulting `.devloop.conf` and require confirmation before the first real gate.

## Step 2 — task file

Create `docs/tasks/<id>.md` from `docs/tasks/TEMPLATE.md`. It must have:

```yaml
---
id: task-001
status: review          # draft | ready | in_progress | review | done | blocked
branch: task/001-slug
created: YYYY-MM-DD
owner: <agent or human>
implementer: <agent>
---
```

plus outcome, acceptance criteria checkable by a command, scope/out-of-scope,
size estimate and risks. If the estimate exceeds `MAX_DIFF_LINES` (default 400),
split now. Do not start coding before the file exists and is committed: `integrate.sh`
reads it from HEAD.

## Step 3 — branch and implement

```bash
git switch -c task/<id>-<slug>
# parallel work: git worktree add ../<repo>-<id> -b task/<id>-<slug>
```

- Small commits, Conventional Commits, imperative, ≤72 characters.
- Tests in the same commit as the behaviour they cover.
- Never weaken, skip or delete a test to pass the gate.
- Protected areas (auth, payments, migrations, CI, secrets): stop and ask first.
- One writer per worktree; never let two agents edit the same worktree.

## Step 4 — gate

```bash
bash scripts/devloop/gate.sh --task <id>
```

- Evidence lives in `$(git rev-parse --git-common-dir)/devloop/gate/<sha>/`, shared
  by every worktree of the repository and never inside the worktree.
- exit 0 + `dirty:false` → continue;
- exit 1 → read the log named in the output, fix, commit, re-run;
- exit 3 → the checks passed but the tree was dirty: **not integrable**, commit and
  re-run. The word `PASSED` is never printed in that case;
- exit 2 → configuration/usage error (no `CHECK_*`, unknown argument).

Never use `--no-verify`, `|| true`, or a loosened assertion to get through.

## Step 5 — independent review

```bash
bash scripts/devloop/packet.sh
# -> .git/devloop/review/<sha>-packet.md
```

Hand the packet path and the task file to a **separate context** (a `subagent`
with no shared history, a teammate, or a human). It follows the installed skill
`.agents/skills/code-review/SKILL.md` and writes `docs/reviews/<task>-r<N>.md`:

```yaml
---
task: task-001
sha: <full HEAD reviewed>
verdict: approve | revise | reject
blockers: 0
reviewer: <name or self>
contract: approved | n/a
date: YYYY-MM-DD
---
```

Rules:

- the review file must be **added after** the commit it reviews; a review
  committed with the code, or modified afterwards, is refused;
- never commit a review before the reviewer reports its final verdict; a draft is
  not evidence. The Lead commits the final file and records its blob;
- `approve` + `blockers: 0` → commit the review, then **re-run the gate** (HEAD moved);
- `revise` → fix the blockers, commit, gate, review round 2; two rounds maximum,
  then escalate to the human with the blocker list;
- you may not review your own diff. Solo fallback: `reviewer: self` + `approved_by:`
  and explicit human approval before integration;
- if the branch touches contract paths (`.devloop.conf`, `scripts/devloop`,
  `.githooks`, workflows, `AGENTS.md`), the review must say `contract: approved`.

## Step 6 — integrate

```bash
bash scripts/devloop/integrate.sh --task <id> --dry-run
bash scripts/devloop/integrate.sh --task <id> [--allow-oversized] [--push|--pr]
```

It refuses unless **all** hold:

1. the committed task file matches `--task` and the current branch, status
   `review` or `done`;
2. the working tree is clean;
3. a passing, non-dirty gate result exists for HEAD;
4. an approving review for this task covers HEAD, was added after the reviewed
   SHA (only `A docs/reviews/` afterwards), and its blob is recorded;
5. contract-path changes are approved by the review;
6. the diff is within `MAX_DIFF_LINES` (or `--allow-oversized`, visible in history);
7. when `REQUIRE_CI=true`, GitHub checks are green for HEAD;
8. the **merge result** passes the gate in a detached worktree.

Integrations are serialized with a lock. In local mode `main` is fast-forwarded (or its ref
updated when it is not checked out); a failing merge gate leaves `main` untouched. `--push`
pushes `main` with `ALLOW_MAIN_PUSH=1` in the environment only; the pre-push hook ignores
`.devloop.conf` on purpose.

On a protected repository (`REQUIRE_PR=true`), use `--pr` instead: it pushes the branch,
opens or reuses a pull request, waits for the required `gate` check, merges with
`gh pr merge --merge --delete-branch`, then **gates the GitHub merge commit locally** and
syncs `main`. `protect.sh` installs/refreshes the protection (required `gate`, admins
enforced, no force-push or deletion). With protection on, the bookkeeping commit
(`STATE.md`/`LESSONS.md`) also goes through a short `state/<sha>` PR; never hand-push `main`.

Protection depends on the GitHub plan: **branch protection and rulesets are unavailable on a
private repository on GitHub Free**. On that plan, the shipped `main-guard` workflow detects a
push to `main` that is not a verified pull-request merge (issue + red job); it is detection,
not prevention. Prevention requires a public repository or GitHub Pro/Team. The PR flow works
either way and `REQUIRE_PR=true` stops the script from using local mode.

## Step 7 — record

Update `docs/STATE.md` (`last_verified_sha` = the merge commit, focus, next
actions). Append one line to `docs/LESSONS.md` if something was learned. Write an
ADR if a decision will constrain future work. Mark the task `done`.

The `review -> done` transition after integration is not covered by the
main-branch bookkeeping exception yet; settle it with an ADR or a follow-up task
rather than editing the task file directly on `main`.

## Team mode

Use this when more than one agent works at once.

| Role | Who | Writes | Runs |
|---|---|---|---|
| Lead | the session talking to the human | task files, packet, `STATE.md`, routing | `gate`, `packet`, `integrate` |
| Implementer | one fresh context per task, `cwd` = its worktree | code, tests, task notes | `gate` |
| Reviewer | a **different** fresh context | the review file only | `packet` review, `gate` |
| Integrator | the Lead, serialized | `main`, integration record | `integrate`, `--push` |

Protocol:

1. Lead writes `docs/tasks/<id>.md`, creates the shared task with its write
   scopes, and creates one worktree per task.
2. Spawn the implementer with `cwd` on that worktree and the task id only. It
   commits, gates, and reports **`SHA + gate result`** — never "done".
3. Lead builds the packet and spawns a **fresh** reviewer with the packet and the
   task file only.
4. The reviewer writes the review file and reports its path + sha256. The Lead
   commits exactly that file (the implementer must not edit it).
5. Lead re-gates, takes the integration lock, integrates **one task at a time**,
   pushes, and updates `STATE.md`.

Rules:

- one writer per worktree; one integrator at a time; no review reused across tasks;
- the board is an ephemeral scheduler: `docs/tasks/` is the durable truth;
- limit to 2–3 tasks in flight; if two tasks touch the same file, sequence them;
- the review file is the handoff artefact: its `task:`, `sha:` and blob are what
  `integrate.sh` checks, not a chat message.

Failure modes to expect:

| Symptom | Cause | Fix |
|---|---|---|
| `no gate result for <sha>` in another worktree | old kit or wrong store | artifacts live under the git common dir; upgrade |
| `'main' is already used by worktree` | integrating from a task worktree with old code | current `integrate.sh` merges in a detached worktree |
| two integrations at once | no lock | `flock` on the common store; serialize |
| review refused as stale | code committed after review | re-review the new HEAD |
| review for another task accepted | old matcher | current matcher requires `task:` match |

## Choosing the mode

| Situation | Mode |
|---|---|
| one small task, one session | you implement, a `subagent` reviews, you integrate |
| several independent tasks | one worktree per task, a fresh implementer per worktree, serialize integrations |
| long project | keep `STATE.md` current; a persisted goal helps, but evidence decides |

## Hard rules

1. Evidence is bound to a SHA; a claim without an artifact is not evidence.
2. No direct commit to `main`; bookkeeping (`docs/STATE.md`, `docs/LESSONS.md`) is
   the only exception, with a `chore(state):` message.
3. One writer per worktree; parallel tasks use separate worktrees.
4. Never edit a committed review or gate result; a change of mind is a new round.
5. No secrets in code, logs, fixtures, commits.
6. If the same refusal happens twice, stop and escalate with the exact command and output.
7. A failing merge gate never moves `main`.
8. Never let a branch unlock its own protection (`.devloop.conf` is ignored by `pre-push`).

## Full procedure after installation

Read `.agents/skills/dev-cycle/SKILL.md` for the operational detail,
`.agents/skills/code-review/SKILL.md` for the rubric, and
`.agents/skills/task-authoring/SKILL.md` for the task format. This skill is the
entry point; those are the reference.

## When not to use this skill

- answering a question, explaining code, or exploring a repository;
- a one-character typo in a comment (the ceremony costs more than the change);
- a repository where the user explicitly does not want commits or branches.
