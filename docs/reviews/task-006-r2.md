---
task: task-006
sha: 7a6dfef7249bd5db7e0709e32c27fc74811c989b
verdict: approve
blockers: 0
reviewer: reviewer-013
contract: approved
date: 2026-10-21
---

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: PR block pushes (`integrate.sh:207`), reuses/creates the PR, refuses an empty check list, watches `--fail-fast` (`:218-222`), merges with `gh pr merge --merge` (`:225`), deletes the remote branch best-effort (`:227`), reads `mergeCommit` (`:228-230`), gates that commit in a detached worktree (`:240-242`), and only then ff/updates local `main` (`:245-251`), recording `mode:"pr"` with `merge_sha`/`merge_gate`. AC2: `bash scripts/devloop/protect.sh --dry-run` emits `required_pull_request_reviews:{required_approving_review_count:0,dismiss_stale_reviews:true}`, `enforce_admins:true`, `allow_force_pushes:false`, `allow_deletions:false`, `contexts:["gate"]` (`protect.sh:40-52`); verified by running it. AC3: `.github/CODEOWNERS` lists the five contract paths; `.devloop.conf:8-9` sets `REQUIRE_CI=true`/`REQUIRE_PR=true`. AC4: bundle mirrors are byte-identical (below). AC5: `bash tests/run.sh` -> `passed: 104, failed: 0`; gate below. AC6: post-merge dogfood, not executable locally by design. AC1's literal `--delete-branch` wording is stale — finding 1, non-blocking. |
| Tests | `tests/run.sh:695` asserts `required_approving_review_count: 0`, so a payload returning `required_pull_request_reviews: null` now fails the suite; `tests/run.sh:697` asserts `allow_deletions: false`; the pre-existing `enforce_admins`/`gate`/`force-push` assertions still run (`:686-698`). Suite is 104/0 and the two new checks fail against the r1 payload (field absent), so they are not vacuous. |
| Test integrity | `git diff 098ad18..HEAD -- tests/run.sh` is 20 added lines, 0 removed (only the `---`/`+++` headers start with `-`); no test skipped, no timeout/sleep changed, no assertion loosened. `tests/run.sh:670-681` keeps the bundle drift checks that would catch a stale mirror. |
| Correctness | Zero-approval case now yields an object, which is GitHub's "Require a pull request before merging" switch, so PRs remain mandatory with count 0 — the exact single-account configuration documented at `protect.sh:9-12`. Local ordering is unchanged and correct: `MERGE_SHA` is read and gated (`:240-242`) before `merge --ff-only origin/main` / `update-ref` (`:248`, `:251`), so a failed gate leaves local `main` untouched and says so. `|| true` on `:227` is a standalone command, so a deletion failure (already-deleted branch, auto-delete setting, permissions) cannot abort after a successful merge. |
| Errors | Distinct die messages for gh missing/unauth, empty checks, red/timeout checks, merge refusal, missing merge SHA, fetch, and merge-gate failure (`integrate.sh:201-245`). The only swallowed status is the branch deletion (`:227`) by design; the merge-gate failure message warns that `main` already contains the commit. No exception loses its cause. |
| Security | No secrets/tokens added; PR body carries only task/review path/blob/SHA (`:208-209`); protect payload is static JSON built with `jq --argjson` from env-approved values; dry-run makes no `gh api` mutation (`protect.sh:50-53`). `enforce_admins:true` closes the direct-push hole that r1 blocked on. |
| Compatibility | `REQUIRE_PR` still defaults to `false` in `common.sh`/`.devloop.conf.example:14`, so downstream installs are opt-in; `dist/devloop-skill/refresh.sh` still copies only `.github/workflows`, so installing cannot clobber a target's CODEOWNERS. Removing `gh pr merge --delete-branch` changes no script interface. |
| Scope | 21 files, 539+/24- = 563 changed lines (`git diff 098ad18..HEAD --numstat`) against `MAX_DIFF_LINES=400`: still oversized, acknowledged and delegated in the task statement; `packet.sh` warns and `integrate.sh` will need `--allow-oversized`. Non-blocking process note, see finding 4. No unrelated refactor in the fix commit. |
| Readability | The fix is a one-line payload change plus a two-line merge/delete split; the PR block stays linear and commented (`:240` announces the merge-commit gate). `|| true` at `:227` is clear but silent — finding 3. |
| Docs | `AGENTS.md:63`, `dist/devloop-skill/SKILL.md`, and `design/04` describe the PR-only path and `state/<sha>` bookkeeping consistently with the now-correct payload. `protect.sh:5-12` documents the zero-approval constraint. The only doc drift is AC1's `--delete-branch` wording — finding 1. |

## Blockers

None.

## Findings (non-blocking)

1. `docs/tasks/task-006.md:22` — AC1 still says `gh pr merge --merge --delete-branch`, but `integrate.sh:225-227` now merges without it and deletes the remote branch separately. This is the r1-recommended fix, so the behaviour is right; per AGENTS.md §5 the task file should *append* a decision recording the deviation rather than leave the acceptance text stale.
2. `tests/run.sh:695` — the count assertion is a substring match, so it proves the field exists but not that `required_pull_request_reviews` is an object; a payload that kept a stray count while emitting the object as `null` cannot occur with the current `jq` literal, but asserting `"dismiss_stale_reviews": true` alongside would pin the whole object. `strict:false` remains unasserted as r1 noted.
3. `scripts/devloop/integrate.sh:227` — the deletion failure is silently discarded (`>/dev/null 2>&1 || true`). Correct for the integration outcome, but a stale remote branch goes unnoticed; printing a one-line warning on failure would preserve observability.
4. Diff size: 563 lines vs `MAX_DIFF_LINES=400`; `packet.sh` warns and `integrate.sh` will refuse the merge without `--allow-oversized`. Justify it in the integration record and split task-007 work.
5. `tests/run.sh` does not cover the branch-deletion path at all (it cannot without a remote). Acceptable for shell-only tests; the dogfood in AC6 is the real check.

## Verdict rationale

The r1 blocker is genuinely fixed: the dry-run payload now keeps "Require a pull request before merging" enabled with `required_approving_review_count: 0`, so an admin's direct push is refused even with zero approvals, and the added assertions make the regression fail the suite. The merge path still gates the GitHub merge commit before touching local `main`, and removing `--delete-branch` in favour of a best-effort remote delete removes the post-merge local-branch failure mode without weakening cleanup. Remaining items are doc and observability nits; AC6 stays pending as the post-merge dogfood.
