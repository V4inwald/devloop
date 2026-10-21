---
task: task-006
sha: bc3c9ee1ae285bf0770054caf31c08a7362a2d20
verdict: revise
blockers: 1
reviewer: reviewer-012
contract: approved
date: 2026-10-21
---

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `integrate.sh:200-270` pushes, reuses/creates the PR, requires ≥1 check (`:218-220`), watches `--fail-fast` (`:222`), merges `--merge --delete-branch` (`:225`), fetches, gates `MERGE_SHA` in a detached worktree (`:231-243`), moves local `main` only afterwards (`:245-252`), records `mode:"pr"` (`:260`). AC2: `protect.sh` dry-run exits 0, but payload has `required_pull_request_reviews:null` — see B1. AC3: `.github/CODEOWNERS:4-9` names all five core contract paths; `.devloop.conf:8-9` sets both flags. AC4: SKILL/AGENTS/README/design diffs read and consistent with the code except the direct-push claim covered by B1. AC5: `bash tests/run.sh` -> `passed: 102, failed: 0`; gate below. AC6: post-merge, cannot be executed here by design. |
| Tests | `tests/run.sh:686-700` adds six assertions: dry-run exit 0, `"gate"` context, no force-push, `enforce_admins`, `--pr`+`--push` refusal, `REQUIRE_PR` local refusal. Suite 102/0. All six pass. |
| Test integrity | Tests diff is additions only; no assertion removed, skipped, or loosened; no timeout/sleep added. `--pr`+`--push` is rejected at `integrate.sh:43` before any file lookup, so the test is real. |
| Correctness | Failure paths inspected: gh missing/unauth (`:201-203`), no checks (`:218-220`), red/timeout checks (`:222-223`), merge refused (`:225-226`), missing merge SHA (`:227-229`), fetch (`:231`), gate (`:239-241`). Local `main` is not touched before the GitHub merge and the merge-commit gate: `MAIN_SHA` is captured at `:234` and the ref/ff update happens only at `:245-252`. |
| Errors | Every failure dies with a distinct message; gate failure after the remote merge correctly says `main already contains it` and leaves local `main` untouched. No swallowed exit codes (`|| true` only on the check probe, which is then validated non-empty). |
| Security | No secrets or tokens introduced; PR body only carries task/review path/blob/SHA (`:208-209`); dry-run performs no `gh api` call and prints a placeholder repo (`protect.sh:31-55`). |
| Compatibility | New `REQUIRE_PR` defaults to `false` in `common.sh:13` and `.devloop.conf.example`; the fixture writes its own `.devloop.conf` with no `REQUIRE_PR`/`REQUIRE_CI` (`tests/run.sh:42-47`), so existing/local test behaviour is unchanged. `refresh.sh:18-20` copies `.github/workflows` only; `dist/devloop-skill/assets/.github` contains only `workflows/`, so an installer cannot clobber a target's CODEOWNERS. |
| Scope | 517 changed lines (`git diff 098ad18..HEAD --numstat`: 493+/24-) against `MAX_DIFF_LINES=400`; oversized, and `integrate.sh` will need `--allow-oversized`. Bundle mirrors are expected, but the task should be split per the review skill. |
| Readability | PR block is linear and commented; `MAIN_WT` lookup is dense but single-purpose. No blocking readability issue. |
| Docs | `AGENTS.md`, `SKILL.md`, `dev-cycle`, `README.md`, `design/04` describe `--pr`, the `state/<sha>` bookkeeping PR, and `protect.sh`. The "direct push to `main` is refused, admins included" claim is not delivered by the current payload — folded into B1. `refresh.sh` CODEOWNERS exclusion is not documented but is correct. |

## Blockers

1. `scripts/devloop/protect.sh:46` — with the default `REQUIRED_APPROVALS=0`, the payload emits `required_pull_request_reviews: null`. That field is GitHub's "Require a pull request before merging" switch: `null` turns it **off**. `enforce_admins:true` plus the required `gate` status check do not require a PR, so a direct push of a commit whose `gate` check is already green (e.g. a reviewed task-branch commit) is accepted. AC2 ("direct-push denial"), AC6 ("a direct push to `main` is rejected"), and the README/AGENTS/design claims are therefore not enforced, and the `--pr` dogfood would not prove them. Smallest fix: always emit `required_pull_request_reviews:{required_approving_review_count:$approvals,dismiss_stale_reviews:true}` — GitHub accepts `0`, which keeps "Require a pull request before merging" enabled with zero approvals — and add an assertion in `tests/run.sh:686-700` that the payload has a non-null `required_pull_request_reviews` with count 0 (plus `allow_deletions:false`). No change is needed to the 0-approval single-account decision itself.

## Findings (non-blocking)

- `scripts/devloop/integrate.sh:225-226` — `gh pr merge --delete-branch` deletes the local head branch after merging; when `main` is already checked out in another worktree (the normal multi-worktree layout this kit supports), the local checkout/switch can fail after GitHub has already merged, and the script would die with "the PR was not merged". Suggested hardening: on merge failure, re-read `gh pr view --json state,mergeCommit` and continue when `state == MERGED`; otherwise die.
- `scripts/devloop/integrate.sh:208-209` — PR body labels the head SHA as `Gate:` and the review path as `Reviewed-by:`; cosmetic, but a reader will misparse it as a reviewer identity.
- `scripts/devloop/protect.sh:29` — `--dry-run` still requires the `gh` binary (no auth/network is used, as documented). Acceptable, but it means the dry-run test cannot run on a machine without `gh`.
- `tests/run.sh:686-700` — the new block does not assert `allow_deletions:false` or `strict:false`; the payload is correct today, but these are the two settings most likely to regress silently.
- Diff size: 517 added+removed lines (`git diff 098ad18..HEAD --numstat`), above `MAX_DIFF_LINES=400`. The oversized diff is acknowledged and delegated in the task statement, so this is only a process note: justify `--allow-oversized` in the merge record and split next time.

## Verdict rationale

The local PR flow is structured correctly — GitHub merges before local `main` moves, and the merge commit is gated before the ref update — and the 102/0 suite plus a clean gate are real. But the branch-protection payload silently disables "Require a pull request before merging" when approvals are 0, which is exactly this repository's single-account configuration; `enforce_admins:true` and a required status check are coherent with zero approvals only when the PR-required object is kept with count 0. As written, the end-to-end `--pr` dogfood would not validate AC6's "direct push rejected", and the docs overstate the guarantee. Fix the payload and its test, then this can be approved for the dogfood merge.
