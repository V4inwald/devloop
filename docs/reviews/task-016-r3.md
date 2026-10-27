---
task: task-016
sha: 0a3e792fe9f35758c968238c121498000a77659d
verdict: approve
blockers: 0
reviewer: reviewer-016
contract: approved
date: 2026-10-27
---

# Review — task-016 round 3 (base-merge verification)

Third review, scoped to the base merge: the content of `task-016` was approved in round 2 on
`13669dcf9c22a8dfc1895bf33ea2ca37d748d327`; this round checks that merging `origin/main` into
`task/016-harness-check` at `0a3e792fe9f35758c968238c121498000a77659d` did not lose, weaken or
smuggle anything. Merge parents: `ccd8025` (branch: the committed r2 verdict) and `82a86dd`
(`origin/main` tip, which contains PR #15 `task-014` and PR #16 `task-015`). Both main-side merges
are ancestors of `origin/main` (`git merge-base --is-ancestor` → true for `82a86dd` and `5826883`).

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `bash scripts/devloop/harness-check.sh` → `harness-check: OK (4 skills, AGENTS.md 142 lines)`, rc 0 (the fourth skill is `harness-improvement`, merged from main; rule 1 accepts it because `AGENTS.md:§11` names it). AC2: the 5 refusal cases are still exercised by the real script — `bash tests/run.sh` shows all 7 `ok` harness-check lines. AC3: `bash tests/run.sh` → `passed: 142, failed: 0`; base is 135 after `task-014` (+1) and the +7 of `task-016` are unchanged → 142, exactly as the merge note states (`docs/tasks/task-016.md:60-62`). AC4: `.devloop.conf:3` still runs the script; `.git/devloop/gate/0a3e792…/result.json` → `"sha": "0a3e792…"`, `"ok": true`, `"dirty": false`, LINT exit 0, TEST exit 0 (15 s, `generated_at 18:55:53Z`, i.e. before this review file existed). AC5: `scripts/devloop/harness-check.sh` and the `dist` mirror are still blob `2a71622` (unchanged since the r2 approval). AC6: `README.md:65` **142 assertions**, `:71` "Adoption opt-in : l'ajouter à `CHECK_LINT`", `:72` "Les quatre skills". AC7: r2 approved `13669dcf` and this file approves the merge HEAD. AC8: `timeout 3 bash scripts/devloop/harness-check.sh --root` → rc 2 with the usage message on stderr. |
| Merge fidelity | `git log --oneline --first-parent 13669dcf..HEAD` → `0a3e792` (merge) + `ccd8025` (docs only: `git show --stat ccd8025` = `docs/reviews/task-016-r2.md \| 61 ++++`, no code). No other branch commit was added; the rest of the range is `origin/main` history (task-014/015) pulled in by the merge. `git diff 13669dcf HEAD -- tests/run.sh scripts/devloop/harness-check.sh .devloop.conf` → only `tests/run.sh` +4 lines (task-014's `integrate stops when the PR needs an owner approval` assertion); **zero diff** for `scripts/devloop/harness-check.sh` and `.devloop.conf`. Approved content is byte-identical: harness-check blob `2a71622`, `.devloop.conf` line `CHECK_LINT` unchanged. `git diff 13669dcf HEAD -- README.md` shows only the legitimate resolution (141 → 142, "trois" → "quatre" skills) plus task-014's new section; the task file gains the 3-line merge note. |
| Tests | `bash tests/run.sh` → `passed: 142, failed: 0` on the merge HEAD; all 7 task-016 harness-check assertions plus task-014's new one are green. The suite was not edited by the merge (only task-014's addition came in from main). |
| Test integrity | `git diff --numstat origin/main..HEAD -- tests/` → `28 0 tests/run.sh` (additions only, no deletion); `git diff 13669dcf HEAD -- tests/run.sh` is exactly the 4-line task-014 assertion, nothing removed or skipped; no sleep/timeout change. |
| Correctness | The merge result is coherent: README arithmetic 135 + 7 = 142 matches the suite; the new skill directory is named in the new `AGENTS.md §11`, so rule 1 still passes on the kit (rc 0, 4 skills); the approved script logic was not touched by the merge. AGENTS.md grew to 142 lines, 8 under the 150 ceiling enforced by rule 4 (`harness-check` output) — the check still governs it, so the budget remains enforced. |
| Errors | `--root` without value → rc 2 immediately (usage on stderr), the r1 hang is still fixed; a gate run on the merge SHA exited 0 on both LINT and TEST. |
| Security | No secret in the branch diff vs `origin/main`; no new input boundary (the merged main content — skill, AGENTS.md §11, identity-model doc — only documents rules and files). The r2 residual (unescaped `${name}` in `grep -E`, `scripts/devloop/harness-check.sh:51`) is unchanged and still bounded to trusted, committed skill-directory names. |
| Compatibility | No behaviour change to the kit's shipped example: mirror blobs identical; `.devloop.conf` opt-in note unchanged; the merged `integrate.sh` owner-approval change is main-side, already reviewed in `docs/reviews/task-014-r1.md`, and makes integration stricter (expects `REVIEW_REQUIRED`), not looser. |
| Scope | Branch-side delta vs `origin/main` is exactly task-016's 6 files plus the two review files: `git diff --shortstat origin/main..HEAD` = 8 files, 390 insertions, 3 deletions. The other 15 files in `13669dcf..HEAD` are main's already-reviewed task-014/015 content (`docs/reviews/task-014-r1.md`, `task-015-r1.md` present in HEAD). |
| Readability | Merge note at `docs/tasks/task-016.md:60-62` explains the base change and keeps AC3 (`134 → 141`) as the historical contract rather than rewriting acceptance text — exactly the append-only rule of `AGENTS.md §5`. |
| Docs | `docs/tasks/task-016.md:60-62` records the base shift and why AC3's numbers are historical; README states the real count (142) and the skill count (4). |
| Size | `common.sh:diff_lines` excludes `docs/reviews/`: `git diff --numstat origin/main..HEAD` filtered → **267 changed lines**, limit `MAX_DIFF_LINES=400` (raw total with review files is 393, also < 400). Headroom is 133 lines. |
| Contract | `.devloop.conf` and `scripts/devloop` are contract paths. The branch-side change only **adds** `scripts/devloop/harness-check.sh` and adds the check to `CHECK_LINT`; `MAX_DIFF_LINES=400`, `REQUIRE_PR=true` and `scripts/devloop/gate.sh` are untouched, nothing is skipped or lowered, and main's new owner-approval in `integrate.sh` raises the bar. Nothing in the loop is weakened: `contract: approved`. |

## Blockers

None. The merge is a faithful fast-forward-equivalent of exactly two branch commits (`0a3e792`
merge + `ccd8025` review-only) on top of the approved `13669dcf`; approved files are unchanged,
the suite is 142/0, the gate artifact for the merge SHA is clean and green, and the diff is
267/400 lines.

## Findings (non-blocking)

- `scripts/devloop/harness-check.sh:51` — unescaped `${name}` in the token regex (skill `a.b`
  matches `aXb`); carried over from r2, still bounded to committed skill names.
- `AGENTS.md` is now 142 lines against the 150 ceiling enforced by rule 4 — only 8 lines of
  headroom for a file that must stay small; worth watching before the next `AGENTS.md` edit.
- `docs/tasks/task-016.md:20-30` — acceptance checkboxes still unchecked; the integrator flips them
  with `status: done`, as recorded in r1/r2.

## Verdict rationale

The merge did what the task note says and nothing else: it brought `task-014`/`task-015` (already
reviewed on `main`) into the branch and resolved the README count to the arithmetically correct
142, while `scripts/devloop/harness-check.sh`, both mirrors and `.devloop.conf` remain byte-identical
to the r2-approved blobs. Evidence regenerated on the merge HEAD: 142/0 tests, rc 0 on the kit,
rc 2 on the malformed invocation, `ok=true dirty=false` gate for `0a3e792`, 267/400 changed lines.
`contract: approved`: the diff still only strengthens the loop. The two carried-over findings are
non-blocking and unchanged from the approved round 2.
