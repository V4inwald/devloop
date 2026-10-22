---
task: task-011
sha: f04d2669dd67ee252644dc5c8c1d39c5808bf01e
verdict: approve
blockers: 0
reviewer: reviewer-019
contract: approved
date: 2026-10-22
---

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `main-guard.yml:35-44` only checks out, runs the anchored mode grep, and calls `bash scripts/devloop/main-guard.sh`; regex exercised manually — accepts `REQUIRE_PR=true`, `REQUIRE_PR="true"`, `REQUIRE_PR='true'`, rejects `REQUIRE_PR=false`, `REQUIRE_PR=true # c`, `#REQUIRE_PR=true`, `REQUIRE_PR=truex`, and a missing file (grep rc 2). AC2: single `exit 1` after `gh issue create` (`main-guard.sh:54-59`); state/mergeCommit/baseRefName checked in order (`:42-47`). AC3: six stub paths pass (`tests/run.sh:725-743`). AC4: gate PASSED on f04d266, `dirty:false`, LINT+TEST exit 0. |
| Tests | `bash tests/run.sh` -> `passed: 125, failed: 0`; `guard_run` executes `bash "$GUARD_LOGIC"` where `GUARD_LOGIC=$SRC/scripts/devloop/main-guard.sh` (`tests/run.sh:675,716-724`), i.e. the real script, not a copy. Parent cannot satisfy them: `git show 565a8b0:scripts/devloop/main-guard.sh` -> rc 128 (file absent), so every new guard assertion fails pre-change. |
| Test integrity | `git diff 565a8b0..f04d266 -- tests/run.sh` removes only four `grep` assertions and retargets them from `$GUARD` to `$GUARD_LOGIC` (`tests/run.sh:676-685`); net +6 assertions (119 -> 125), no skip, no sleep, no timeout change, no assertion deleted outright. |
| Correctness | Branch deletion short-circuits on the all-zero SHA (`main-guard.sh:17-21`); PR number is extracted digit-only and compared against `MERGED`, `mergeCommit.oid == SHA`, `baseRefName == BASE_BRANCH` (`:30-47`); empty PR read is reported, not treated as success (`:36-37`). |
| Errors | `gh api` is wrapped `2>/dev/null | head -1 || true` (`:23`), so an API failure flows to `reason` and to the issue instead of aborting; every failure branch assigns `reason` and falls through to `gh issue create` then `exit 1` (`:54-59`); a failing issue create still exits 1 (`|| true`, `:57`). Tested explicitly by the `FAKE_API_FAIL=1` case (`tests/run.sh:737-739`). |
| Security | Extracted `$pr` matches `[0-9]+` only and is passed quoted to `gh pr view` (`main-guard.sh:30,34`); the commit subject is only piped to `sed` via `printf` and echoed, never eval'd or interpolated into a command; `REPO`/`SHA` are quoted; no secret added. Shell injection via the subject is not reachable. |
| Compatibility | Bundle mirrors the source: `scripts/devloop/main-guard.sh` and `dist/devloop-skill/assets/scripts/devloop/main-guard.sh` share blob `4d91961`; both `main-guard.yml` files are identical (`diff -q` rc 0) and the bundle tests pass (`tests/run.sh:686-687,754-755`). No interface/format change beyond the documented workflow contract. |
| Scope | `git diff --numstat` 226 added + 93 deleted = 319 changed lines, under `MAX_DIFF_LINES=400` (`scripts/devloop/common.sh:11,92`); 7 files, all in the announced area plus the README assertion count. No dependency or unrelated refactor. |
| Readability | 59-line script with a header explaining why the logic moved (`main-guard.sh:1-8`); one reason funnel and one exit path; workflow reduced to 44 lines with the mode decision isolated in its own step. |
| Docs | Task outcome, scope, risks and verification plan in `docs/tasks/task-011.md`; the script header and workflow comment record the testability rationale; README test count updated 119 -> 125 to match reality. |

## Blockers

None.

## Findings (non-blocking)

1. `scripts/devloop/main-guard.sh` is executable on disk (`-rwxr-x--x`) but recorded as `100644` in git; `core.fileMode=false` records every `scripts/devloop/*` script the same way. Both call sites use `bash <path>` (`main-guard.yml:44`, `tests/run.sh:722`), so behaviour is unaffected; commit the mode only if direct `./` execution is ever expected.
2. The mode regex in `main-guard.yml:30` has no automated test: `tests/run.sh` only checks that the workflow mentions `REQUIRE_PR` (`tests/run.sh:682-683`). The three accepted and five rejected forms above were verified manually; a regression would only surface in CI.
3. The stub `gh` `pr view` ignores its PR-number argument and `issue create` only logs `"$*"` (`tests/run.sh:706-709`), so the tests do not assert that `#42` was queried or that the reason text reached the issue body — only that an issue was attempted. Low risk; the reason strings are exercised indirectly.
4. `README.md` is updated (119 -> 125) but is not listed in the task Scope (`docs/tasks/task-011.md:28-29`). Bookkeeping only.
5. `reason` labels an empty but readable commit message as an API failure (`main-guard.sh:27-28`). Mislabel in a rare edge case; it still fails closed.
6. The packet header reports `diff lines: 415` (raw `git diff`, context included) while `integrate.sh` counts 319 changed lines via `diff_lines` (`scripts/devloop/common.sh:92`). The enforced limit passes; the packet figure is only display and predates this task.

## Verdict rationale

The guard logic is now a standalone script with one failure funnel, every rejection path creates an issue before `exit 1`, and the commit-API failure no longer aborts. Six stub-`gh` tests drive the real script and would fail against the parent, while the workflow is reduced to checkout, mode decision, and one `bash` call. The base check and digit-only PR extraction close the injection and wrong-branch paths; remaining observations are non-blocking.
