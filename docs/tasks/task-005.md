---
id: task-005
status: done
branch: task/005-skill-team
created: 2026-10-21
owner: lead
implementer: lead
---

# Aligner le skill et le mode équipe avec le moteur

## Outcome

A fresh agent can read the installed skill and run the real loop — shared
artifacts, task contract, immutable review, merge gate, `--push`, parallel
worktrees — without reading the scripts, and the distributed bundle matches the
source it documents.

## Acceptance criteria

- [x] AC1: `dist/devloop-skill/SKILL.md` documents install (non-destructive, `--dry-run`/`--force`), the shared store, gate exit 0/1/3, the task contract, the review blob/`contract:` field, the merge gate, `--push`, and a "Team mode" protocol.
- [x] AC2: `AGENTS.md`, `README.md`, `design/01`, `design/04`, `packet.sh` and `.devloop.conf.example` match the current paths and commands; the old `.devloop/artifacts` path no longer appears in the hot docs.
- [x] AC3: `dev-cycle`, `code-review` and `task-authoring` describe the current procedure (review added after the SHA, blob pinned, contract approval, one integrator, worktrees).
- [x] AC4: the bundle is refreshed and byte-identical to the source for every mirrored path; tests assert the drift.
- [x] AC5: `bash tests/run.sh` passes (drift assertions included) and `gate.sh` is clean.

## Scope

Touched: `dist/devloop-skill/SKILL.md`, `.agents/skills/*/SKILL.md`, `AGENTS.md`,
`README.md`, `design/01-architecture.md`, `design/04-gates-and-review.md`,
`scripts/devloop/packet.sh`, `.devloop.conf.example`, `tests/run.sh`,
`docs/tasks/task-005.md`, and the refreshed `dist/devloop-skill/assets/`.

Out of scope: new helper scripts (`worktree.sh`, `report.sh`), GitHub branch
protection/PR mode (task-006), AC-as-code and mutation checks (task-007).

## Verification plan

1. `bash tests/run.sh` — 96 assertions (90 + 6 drift).
2. `bash scripts/devloop/gate.sh`.
3. Read `dist/devloop-skill/SKILL.md` and follow Step 6 without reading the scripts.

## Risks

- Documentation drifts quickly: the drift tests cover the store path, the team
  mode section and the bundle mirror, not every sentence.
- The bundle duplicates the source; `refresh.sh` remains a manual step.
- `design/02` (packaging) and `design/06` (roadmap) are not updated here; they
  are historical design notes, not operational docs.

## Notes / decisions

- 2026-10-21: the entry skill now states the two rules that were missing and
  that caused real incidents: a review is added **after** the reviewed commit
  (never committed as a draft), and a branch cannot unlock its own push
  protection (`.devloop.conf` is ignored by `pre-push`).
- The bundle mirror is now checked by the test suite; any future engine or skill
  change that forgets `refresh.sh` fails the gate.
