---
task: task-006
sha: b2d1b7fd2f69e13df799c65c816118c61c166db6
verdict: approve
blockers: 0
reviewer: reviewer-014
contract: approved
date: 2026-10-21
---

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1 (delta): push `integrate.sh:205`; reuse filters `--state open` (`:206`); create/read PR (`:208-215`); bounded registration poll (`:220-224`); missing suite dies (`:226-227`); red/timeout suite dies via `--watch --fail-fast` (`:229-230`); `gh pr merge --merge` (`:232`); remote branch deleted separately, non-fatal (`:234`); merge commit read and gated in a detached worktree (`:235`, `:247-250`) before local `main` moves (`:253-258`). AC2/AC3/AC5 unchanged since r2; AC4 bundle byte-identical; AC6 dogfood still post-merge by design. |
| Tests | `bash tests/run.sh` -> `passed: 104, failed: 0` (exit 0). Delta adds no test because the race needs live GitHub check registration; the reachable surface stays covered by the "github arbiter" group (`--pr`/`--push` exclusion, `REQUIRE_PR` refusal). |
| Test integrity | `git diff --numstat 7a6dfef..HEAD` lists no `tests/` file: 4 files, 64+/9-, of which `tests/run.sh` is absent. No assertion removed, no timeout raised, no test skipped. `sleep 5` at `:224` is production polling, not a test sleep, and is bounded. The bundle drift test ("bundle scripts mirror the source") ran and passed in the same suite. |
| Correctness | Loop is bounded: `seq 1 24` x `sleep 5` = 120s (`:221-224`), and the only exit paths are `CHECKS_READY=1` or the `die` at `:226-227` — no unbounded wait. A missing suite still dies; a red suite still dies at `:229-230` before the merge at `:232`. Local `main` is touched only after `MERGE_SHA` is gated (`:247-250`) and the fast-forward/update-ref (`:253-258`), so a red merge gate leaves local `main` untouched. `--state open` (`:206`) prevents merging a closed PR. |
| Errors | Distinct `die` messages for gh missing/unauth (`:201-202`), push (`:205`), PR create/read (`:212-214`), no suite after 2 min (`:227`), red/timed-out checks (`:230`), merge refusal (`:233`), missing merge SHA (`:236-237`), fetch (`:239`), merge-gate failure (`:249`). `:234` swallows the branch-deletion status by design; `:222` swallows poll errors — finding 1, fail-closed. |
| Security | No secret, token, or credential added. The PR body still carries only task/review/blob/SHA (`:208-209`). Deletion targets the pushed branch variable; the merge is executed by GitHub's arbiter, not by a local bypass. |
| Compatibility | No CLI/interface change: `--pr`/`--push` semantics untouched, `REQUIRE_PR` default unchanged. Behaviour change is strictly a narrower reuse filter plus a bounded wait; `CI_WAIT_SECONDS` still governs the watch at `:229`. Bundle refreshed (`dist/devloop-skill/assets/scripts/devloop/integrate.sh`), so installs get the fix. |
| Scope | `7a6dfef..HEAD` is 4 files: `scripts/devloop/integrate.sh` (11+/4-), its bundle copy (identical 11+/4-), `docs/tasks/task-006.md` (2+/1-), and `A docs/reviews/task-006-r2.md` (the r2 verdict, added after its reviewed SHA — the only tolerated non-code addition). `cmp` confirms source and bundle are byte-identical at HEAD. Cumulative 563 lines vs `MAX_DIFF_LINES=400` is inherited from r2, not introduced here. |
| Readability | The new block is linear and commented with the reason (`:218-219`), the 24x5s is visible at the loop head, and the readiness flag makes the failure explicit. No dead code left from the old single-read. |
| Docs | `docs/tasks/task-006.md:20-22` rewrites AC1 to "waits for the check suite to register" and "merges with `gh pr merge --merge`", and the Note records both the `--delete-branch` removal rationale and the async check-registration race. The bundle `SKILL`/AGENTS text needed no change (they describe PR mode, not the poll). |

## Blockers

None.

## Findings (non-blocking)

1. `scripts/devloop/integrate.sh:222` — the poll discards gh's stderr and exit status, so a transient auth/network failure is indistinguishable from "suite not registered yet"; after 120s the operator is told "enable the workflow", which can be the wrong cause. Fail-closed, and it matches the pre-existing style, but capturing the last failed attempt's stderr into the `die` would keep observability.
2. `scripts/devloop/integrate.sh:221-227` — "after 2 minutes" is 24 iterations each doing a `gh` call plus `sleep 5`, so the wall clock slightly exceeds 120s on a slow network. Cosmetic: the bound is real; the message just understates it.
3. `docs/reviews/task-006-r2.md` — the r2 verdict was added inside code commit `b2d1b7f`, so one commit carries both a verdict on `7a6dfef` and code that verdict never saw. Ordering is still correct (file added after its reviewed SHA) and `integrate.sh` tolerates `A docs/reviews/`, but a Lead commit for the review file keeps the audit trail clean.
4. AGENTS.md §7 caps reviews at two rounds; this `r3` is a human-directed delta review, so it is an accepted exception rather than a silent round 3. Record it in the integration record.
5. `scripts/devloop/integrate.sh:206` — if a closed, unmerged PR exists for the branch, `gh pr create` refuses (typically "a pull request already exists") and the script dies at `:212` with no hint to reopen or rename. Fail-closed and out of scope for this delta; worth a clearer message later.
6. `tests/run.sh` cannot cover the poll or the PR merge offline; the registration race is only observable in the AC6 dogfood. Stated in the task file, so not a hidden gap.
7. Inherited from r2: cumulative diff of 563 lines exceeds `MAX_DIFF_LINES=400`; `integrate.sh` will need `--allow-oversized`, and task-007 should be split.

## Verdict rationale

The check-registration race is closed: the poll is hard-bounded at 24x5s, a suite that never appears still dies, a red or timed-out suite still dies before `gh pr merge`, and local `main` is still updated only after the GitHub merge commit passes the gate in a detached worktree. The `--state open` filter and the separate, non-fatal remote deletion remove the two remaining reuse/cleanup failure modes, the bundle is byte-identical, no test was weakened, and the PR path is ready for the AC6 dogfood after merge.
