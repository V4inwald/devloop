---
id: task-013
status: review
branch: task/013-prove-red
created: 2026-10-22
owner: lead
implementer: lead
---

# `prove-red.sh` : démontrer qu'un test échoue sans le correctif

## Outcome

A small tool copies the changed test files into a detached worktree at a base commit, runs the
project's test command there, and succeeds only when the command fails — proving the test is
red without the change. It also fixes the stale installer docs found in the task-012 review.

## Acceptance criteria

- [x] AC1: `scripts/devloop/prove-red.sh <base> -- <command>` copies only the changed test files, runs the command in a base worktree, exits 0 on red, 1 when the command passes on base, 2 on usage/no test changes.
- [x] AC2: `tests/run.sh` proves both directions on a throwaway repo (red test -> 0, base-green test -> 1).
- [x] AC3: SKILL/dev-cycle/README document the tool; the SKILL installer backup path and install.sh exit-4 help are corrected.
- [x] AC4: tests, gate and doctor pass; bundle refreshed.

## Scope

Touched: `scripts/devloop/prove-red.sh`, `tests/run.sh`, `dist/devloop-skill/SKILL.md`,
`dist/devloop-skill/install.sh`, `.agents/skills/dev-cycle/SKILL.md`, `README.md`,
`docs/tasks/task-013.md`, refreshed bundle.

## Verification plan

1. `bash tests/run.sh` (>= 134 assertions).
2. `bash scripts/devloop/gate.sh`.
3. PR merge under protection.

## Risks

- The base worktree has no untracked dependencies (for example `node_modules`); a command that
  needs them can fail for the wrong reason. The tool is for self-contained test commands; the
  task notes this.
- The worktree removes on exit; a killed process can leave one under the temp dir.
