---
name: devloop
description: Install and run a SHA-bound development loop in a repository — task file, branch, commits, gate, independent review, integration. Use when a change must be tested, reviewed and merged with evidence rather than trusting an agent's summary. Also use to set up this workflow in a project that does not have it yet.
whenToUse: The user asks for a code change in a devloop-enabled repository, asks to install or try the devloop workflow, asks for a revue/tests/commits propres, or asks to "use the skill devloop" (French or English).
---

# devloop — callable procedure

This skill gives you the full loop in any repository. It is self-contained: the enforcement
files (gate, review, integration, hooks, templates) are bundled in `assets/` next to this file.

The base directory of this skill is shown in your skill header. Call it `SKILL_DIR` below.

## Step 0 — inspect before acting

Run and read the output:

```bash
git rev-parse --show-toplevel 2>/dev/null || echo "NO REPO"
ls .devloop.conf scripts/devloop/gate.sh AGENTS.md 2>/dev/null
git status --short
```

Three cases:

| State | Action |
|---|---|
| no git repository | ask the user whether to `git init`; do not create one silently |
| repo without `.devloop.conf` | install, Step 1 |
| repo with `.devloop.conf` | skip to Step 2 |

If the user only asked a question or a quick look, do not run the pipeline. This skill is for
changes that must be reviewed and merged.

## Step 1 — install (once per repository)

```bash
bash "<SKILL_DIR>/install.sh"
```

It copies scripts, hooks, skills and templates, installs `core.hooksPath`, and writes
`.devloop.conf` from the example. It refuses to overwrite an existing installation unless
`--force`, never overwrites `AGENTS.md`, and puts the contract in `AGENTS.devloop.md` when an
`AGENTS.md` already exists (merge it by hand: DSH only auto-loads `AGENTS.md`/`CLAUDE.md`).

Then adapt `.devloop.conf` to the real project. Infer before asking:

- `package.json` scripts (`test`, `lint`, `build`);
- `Makefile` targets;
- `pyproject.toml` / `Cargo.toml` / `go test`;
- existing CI workflow commands.

Rules for the config:

- at least one `CHECK_*` must be non-empty, otherwise the gate errors;
- never put `true` or a command that cannot fail;
- prefer a fast test command for `CHECK_TEST`; if the full suite is slow, add a separate
  `CHECK_INTEGRATION` and run it before integration, not on every commit.

Show the user the resulting `.devloop.conf` and require confirmation before the first real gate.

## Step 2 — task file

Create `docs/tasks/<id>.md` from `docs/tasks/TEMPLATE.md`. It must have: outcome, acceptance
criteria checkable by a command, scope + out of scope, size estimate, risks.

- If the estimated diff exceeds `MAX_DIFF_LINES` (default 400), split the task now.
- Do not start coding before the file exists.

## Step 3 — branch and implement

```bash
git switch -c task/<id>-<slug>
```

- Small commits, Conventional Commits, imperative, ≤72 characters.
- Tests in the same commit as the behaviour they cover.
- Never weaken, skip or delete a test to pass the gate.
- Protected areas (auth, payments, migrations, CI, secrets): stop and ask the human first.

## Step 4 — gate

```bash
bash scripts/devloop/gate.sh --task <id>
```

- exit 0 with `dirty=false` → continue;
- exit 1 → read the log named in the output, fix, commit, re-run;
- never use `--no-verify`, `|| true`, or a loosened assertion to get through.

## Step 5 — independent review

```bash
bash scripts/devloop/packet.sh
```

Hand the resulting packet path and the task file to a **separate context**: a `subagent` with
no shared history, a teammate, or the human. Ask it to follow the installed skill
`.agents/skills/code-review/SKILL.md` and to write `docs/reviews/<task>-r1.md` with
`sha:` = reviewed HEAD, `verdict:`, `blockers:`.

- `approve` + `blockers: 0` → commit the review file, then **re-run the gate** (HEAD moved);
- `revise` → give the blockers to the implementer, fix, commit, gate, round 2;
- two rounds maximum, then escalate to the human;
- you may not review your own diff. Solo fallback: `reviewer: self` + explicit human approval
  before integration.

## Step 6 — integrate

```bash
bash scripts/devloop/integrate.sh --task <id> --dry-run
bash scripts/devloop/integrate.sh --task <id>
```

It refuses without a passing clean gate for HEAD and an approving review covering HEAD. If it
refuses, fix the cause; a manual merge is out of the contract.

## Step 7 — record

Update `docs/STATE.md` (`last_verified_sha` = the merge commit, focus, next actions). Append one
line to `docs/LESSONS.md` if something was learned. Write an ADR if a decision will constrain
future work. Mark the task `done`.

## Hard rules

1. Evidence is bound to a SHA; a claim without an artifact is not evidence.
2. No direct commit to `main`; bookkeeping (`docs/STATE.md`, `docs/LESSONS.md`) is the only
   exception, with a `chore(state):` message.
3. One writer per worktree; parallel tasks use separate worktrees.
4. Never edit a committed review or gate result.
5. No secrets in code, logs, fixtures, commits.
6. If the same refusal happens twice, stop and escalate with the exact command and output.

## Choosing the mode

| Situation | Mode |
|---|---|
| one small task, one session | you implement, a `subagent` reviews, you integrate |
| several independent tasks | one worktree per task, one subagent each, serialize integrations |
| long project | keep `STATE.md` current; use a persisted goal, but evidence still decides |

## Full procedure after installation

Once installed, read `.agents/skills/dev-cycle/SKILL.md` for the operational detail,
`.agents/skills/code-review/SKILL.md` for the rubric, and `.agents/skills/task-authoring/SKILL.md`
for the task format. This skill is the entry point; those are the reference.

## When not to use this skill

- answering a question, explaining code, or exploring a repository;
- a one-character typo in a comment (the ceremony costs more than the change);
- a repository where the user explicitly does not want commits or branches.
