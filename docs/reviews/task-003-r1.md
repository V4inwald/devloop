---
task: task-003
sha: e8c33ea708d98d72117ada9b6883100d588e055b
verdict: approve
blockers: 0
reviewer: reviewer-009
contract: n/a
date: 2026-10-21
---
## Evidence
| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `DEVLOOP_ARTIFACTS=/tmp/review-global bash tests/run.sh` -> `passed: 68, failed: 0`, exit 0. AC2: `bash scripts/devloop/gate.sh` -> exit 0, `.git/devloop/gate/e8c33ea.../result.json` has `"sha": "e8c33ea708d98d72117ada9b6883100d588e055b"`, `"dirty": false`, `"ok": true`. AC3: reproduced pre-fix at 6fbec9d in `/tmp/review-parent` with `DEVLOOP_ARTIFACTS=/tmp/review-global2 bash tests/run.sh` -> `passed: 53, failed: 15`, exit 1 — exactly matching CI run 39637592566 (53/15); post-merge run remains a STATE check, not a pre-merge criterion. |
| Tests | The change is harness-only, so the existing 68 assertions are the regression test: they fail 15/68 with the variable set on the parent commit and pass 68/68 after, without any new fixture logic. No product behaviour is asserted by this diff. |
| Test integrity | `git diff main..HEAD -- tests/run.sh` is a 5-line pure addition (619 -> 624 lines); zero deleted/modified assertions, no `skip`/`todo`, no timeout or sleep change. Assertion count is unchanged at 68. |
| Correctness | `tests/run.sh:11` unsets `DEVLOOP_ARTIFACTS DEVLOOP_CONF DEVLOOP_LEGACY_ARTIFACTS` at startup, before `setup` is called (`setup` at `tests/run.sh:126`) and before the fixture repo and its `.devloop.conf` are created (`setup` body `tests/run.sh:29-72`). Explicit per-command overrides still work: `tests/run.sh:188` passes `env DEVLOOP_CONF="$TMP_CONF"`, so the unset removes only inherited values. Root cause confirmed in `.github/workflows/ci.yml:28`, which sets `DEVLOOP_ARTIFACTS: ${{ runner.temp }}/devloop` for the gate step. |
| Errors | Failure mode is a fixture writing evidence into the caller's global store; the fix removes the inherited state instead of swallowing a failure, and the suite still exits non-zero on assertion failure (verified at 6fbec9d: exit 1 with 15 FAIL lines). |
| Security | Three environment variables are cleared in a throwaway test process; no secrets, paths from user input, or injection surface introduced. No secret or runner path is logged. |
| Compatibility | No public interface, format, or config change: the top-level gate still honours `DEVLOOP_ARTIFACTS` by design (documented in the task file), and the CLI env contract is untouched. |
| Scope | `git diff main..HEAD --stat` -> `docs/tasks/task-003.md` (+48) and `tests/run.sh` (+5); no production code, no workflow edit, well under `MAX_DIFF_LINES`. |
| Readability | The 4-line comment at `tests/run.sh:8-10` states why the unset exists and what breaks without it; names match the config keys. |
| Docs | `docs/tasks/task-003.md` records outcome, acceptance criteria, scope, risks, and the 2026-10-21 decision note tying the change to CI run 39637592566. |

## Blockers
None.

## Findings (non-blocking)
1. `tests/run.sh:11` implements isolation only in this harness. Any future fixture runner (e.g. a second test script) would inherit the gate's `DEVLOOP_ARTIFACTS` and reintroduce the same class of bug. A hardening option for a later task is for `scripts/devloop/gate.sh` to run each configured check with `env -u DEVLOOP_ARTIFACTS -u DEVLOOP_CONF -u DEVLOOP_LEGACY_ARTIFACTS`, making isolation a property of the gate rather than of one caller. Not required here: the task explicitly scoped the fix to `tests/run.sh`.
2. Because `DEVLOOP_CONF` is unset at startup, inherited-config coverage is no longer exercised implicitly; it is still exercised explicitly at `tests/run.sh:188`, so no coverage is lost today.
3. `docs/tasks/task-003.md` AC3 is checked `[x]` while its second half (post-merge GitHub Actions run recorded in STATE) is still pending; acceptable because the task text itself classifies it as post-integration, but STATE must be updated with the run id after the push.

## Verdict rationale
The diff is a minimal, correctly placed harness fix that reproduces the exact CI numbers (53/15) on the parent commit and yields 68/0 with the variable set at HEAD, with an independently re-run gate at the reviewed SHA (`dirty:false`, `ok:true`). No test was removed, weakened, or skipped. The post-merge CI run is a post-integration STATE check, not a pre-merge criterion.
