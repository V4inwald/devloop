---
task: task-017
sha: 86106e9b91194a09de1dfc04493fd0f2b181d6da
verdict: approve
blockers: 0
reviewer: reviewer-015
contract: n/a
date: 2026-10-27
---

# Review — task-017 round 2

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `docs/harness/PROBES.md:17-24` = six rows P1–P6 with PASS/FAIL columns, variants `:26-32`, baseline `:34-47` (unchanged, still true). AC2: SHA `8e2e254` at `:34`, P1–P3 at `:40-42`, honest limit at `:45-47`; that SHA predates task-015 (`git show 8e2e254:AGENTS.md \| grep -c 'Operating rules'` → 0; no `harness-improvement` skill at that tree). AC3: `Statut : accepted` at `docs/adr/0003-harness-improvement-loop.md:3`; Contexte `:9`, Décision `:19`, Conséquences `:29`, Alternatives écartées `:38`. AC4: the r1 blocker is fixed — `docs/tasks/task-017.md:26` and `:39` now read `test -f .githooks/commit-msg && test -f scripts/devloop/policy.sh`, reproduced at rc 0. AC5: `.git/devloop/gate/86106e9b91194a09de1dfc04493fd0f2b181d6da/result.json` names this SHA, `dirty:false`, `ok:true`, LINT 0, TEST 0 (`passed: 135, failed: 0`). AC6: this file. |
| Tests | The branch gate ran the pre-merge suite (135/0). I also gated the real merge result: `git worktree add --detach /tmp/w17 86106e9 && git merge origin/main` → rc 0; `bash scripts/devloop/harness-check.sh` → `harness-check: OK (4 skills, AGENTS.md 142 lines)`, rc 0; `bash tests/run.sh` → rc 0, `passed: 142, failed: 0`. This is the result `integrate.sh` will gate, and it is green. Worktree removed afterwards. |
| Test integrity | `git show --stat 86106e9` → only the 3 docs files (16+/11−). Branch diff against the merge base touches 0 test lines; no assertion, skip or timeout changed. |
| Correctness | All r1 findings were addressed and are true on this tree. `docs/adr/0003-harness-improvement-loop.md:32` "Le gate échouera (task-016)" matches `origin/main`'s `harness-check.sh` (rules 1–4 in its header, `MAX_AGENTS_LINES=150` at `:16`, line cap `:75-76`) wired into `origin/main`'s `.devloop.conf:3`. The on-demand claim at ADR `:43-44` is verified against the official prompts: `harness2/core/prompts.py` (`_SURFACE_OPENCODE`/`_SURFACE_CODEX`) says "So prefer, in this order: … ALWAYS-ON TEXT last". Cost range at ADR `:35` matches both counts: §11 block = 16 lines with heading/blank, AGENTS.md net growth = +12 (128 → 140). Header `:5-7` now has Décideurs/Tâches plus the French-form note ("owner/reviewer" is an established role: `AGENTS.md:68`, `docs/security/identity-model.md:40`). PROBES `:54` now uses `task-NNN`. Baseline citations still exact on `origin/main`: `.githooks/commit-msg:14` and `scripts/devloop/policy.sh:21` both hold the same `CONVENTIONAL` regex. |
| Errors | Not applicable: no runtime path changed; the four files are Markdown. |
| Security | `grep -rniE '(api[_-]?key\|secret\|password\|passwd\|token\|bearer)[[:space:]]*[:=]'` on PROBES.md, ADR 0003, task-017.md and the committed r1 review → rc 1 (no match). |
| Compatibility | No mirror or contract path in the branch diff (`docs/` only); `CONTRACT_PATHS` = `.devloop.conf scripts/devloop .githooks .github/workflows AGENTS.md` (`scripts/devloop/common.sh:23`), so `contract: n/a`. Merge with `origin/main` is conflict-free (`git merge-tree --write-tree origin/main HEAD` → rc 0) and the merged tree passes harness-check and all tests. |
| Scope | The branch's own diff, base = `git merge-base origin/main HEAD` = `82a86dd`, is 4 files: `docs/harness/PROBES.md`, `docs/adr/0003-harness-improvement-loop.md`, `docs/tasks/task-017.md`, `docs/reviews/task-017-r1.md`; `git diff --numstat 82a86dd..HEAD` sums to 205 changed lines including the r1 review (161 once `docs/reviews/` is excluded, the `diff_lines` count; text lines 229), below 400. `git diff --name-only origin/main..HEAD` now reports 13 files because `origin/main` advanced to `ea87a68` (PR #17, task-016) while this branch forked at `82a86dd`; `integrate.sh` measures the merge base and excludes `docs/reviews/` (`common.sh:65-78`, `92-94`, `integrate.sh:166`) → 161, so the size gate is not the 428 of the stale comparison. |
| Readability | PROBES.md 57 lines; ADR 50 lines, 5 required sections + Suivi; the two changed regions are short and concrete. |
| Docs | ADR records the decision, consequences, discarded alternatives and follow-up; probes record protocol, baseline provenance and the honest limit; the task Notes `:51-54` keep the P4–P6 omission explicit. |

## Blockers

None.

## Findings (non-blocking)

- Process note: `git diff --name-only origin/main..HEAD` is no longer docs-only — `origin/main` moved to `ea87a68` (task-016 merged) and the branch still forks at `82a86dd`, so that comparison lists 13 files and 428 changed lines including the *reversal* of task-016. The correct comparison, and what `integrate.sh` uses, is the merge base: 4 docs files, 205 lines. Do not rebase or merge `origin/main` into the branch after this review — the added commit would invalidate it; `integrate.sh` merges cleanly (verified) and the merged result is green.
- `docs/adr/0003-harness-improvement-loop.md:7` — "les ADR 0001/0002 restent en anglais" is slightly inexact: ADR 0002 has a French title and a French "Alternatives considérées" section (`docs/adr/0002-task-status-and-bookkeeping.md:1,44`). "restent dans leur forme actuelle" would be exact. No impact on the decision.
- Record note: the committed r1 file (77ec4f5) carries `reviewer: reviewer-017`, an off-roster label. It is left untouched as evidence (§2 rule 7); this round signs `reviewer-015`, and the r1 verdict is `revise`, so it is not used for this approval.

## Verdict rationale

The only r1 blocker — the invalid `test -f` command — is fixed in both places and reproduces at rc 0, and every r1 finding was addressed with text that is true on this tree: the task-016 gate exists on main and enforces the four rules, the official prompts do put on-demand components before always-on prose, the cost range covers both counts, and the registration example is neutral. All six acceptance criteria are met at `86106e9`, the branch diff is four docs files and 205 lines against the merge base, there is no secret, and the exact merged result `integrate.sh` will gate passes `harness-check` and the full suite (142/0). The stale `origin/main..HEAD` comparison is a reporting artifact of main having advanced, not a defect in this change, so it does not block approval.
