---
task: task-010
sha: cfece0e823165a11e289852089a0d15b77ce0729
verdict: approve
blockers: 0
reviewer: reviewer-018
contract: approved
date: 2026-10-21
---

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `scripts/devloop/doctor.sh:102-105` defines `BOOKKEEPING_RE='^docs/(STATE|LESSONS)\.md$|^docs/tasks/[^/]+\.md$'` under an ADR 0002 comment. AC2: suite fails on the parent doctor (see Tests). AC3: `bash tests/run.sh` -> `passed: 119, failed: 0`; `bash scripts/devloop/gate.sh` -> exit 0, `result.json` `sha=cfece0e…, dirty:false, ok:true`, LINT/TEST exit 0; `doctor.sh` at 39fe4f7 -> `0 error(s)`. AC4 is a post-review state-PR step; see finding 3. |
| Tests | `tests/run.sh:497-508` appends to `docs/STATE.md` **and** `docs/tasks/task-001.md` (both exist on the fixture `main`, so both are modifications) and commits them together. Regression proven in `/tmp/dr-pre` (HEAD tree with only the two `doctor.sh` files restored to 39fe4f7): `bash tests/run.sh` -> `passed: 117, failed: 2`, `FAIL doctor accepts STATE and task-status bookkeeping` with `ERROR no gate result for HEAD` / `ERROR no approving review file covers HEAD`. Same tree at cfece0e -> 119/0. |
| Test integrity | Assertion count unchanged (119 before and after: 117+2 fails on parent). No assertion deleted, skipped, no timeout/sleep added; the only test edit replaces the generic label with the specific `doctor accepts STATE and task-status bookkeeping` while keeping the same `D_CODE` check and the "names the bookkeeping commit" check. |
| Correctness | Two call sites now share the constant: `doctor.sh:111` (HEAD^ diff detection) and `doctor.sh:187` (STATE `last_verified_sha` check); no other literals of the old regex remain (`grep -n 'docs/(STATE|LESSONS)' scripts/devloop/doctor.sh` -> only the constant). Fail-closed preserved: `doctor.sh:126-128` still errors when the parent is not an integration merge; if a non-bookkeeping file is in the diff, `grep -vE` leaves an offender and the old gate/review path runs. No regex injection: the pattern is a fixed constant, never built from repository data. |
| Errors | Missing/odd paths fail closed: `git diff --name-only` quoting a pathological name makes it an offender, never bookkeeping. The STATE branch only prints OK when `HEAD^ == last_verified_sha` and every changed path matches; otherwise the pre-existing WARN. |
| Security | No secrets, no eval, no path traversal: verified `docs/tasks/sub/x.md`, `docs/tasks/../STATE.md`, `docs/tasks/x.txt`, `docs/STATE.md.bak`, `docs/STATE.md/x`, `scripts/devloop/doctor.sh`, `tests/run.sh` do **not** match the ERE; only `docs/STATE.md`, `docs/LESSONS.md`, `docs/tasks/<single-segment>.md` do (`grep -E` probe). |
| Compatibility | Behaviour change only; shared artifact store, integration records, gate result format untouched. ADR 0002 already permits the widened bookkeeping, so no new format or migration is needed. |
| Scope | `git diff --stat 39fe4f7 cfece0e` -> 4 files, `57 insertions(+), 7 deletions(-)` = 64 changed lines, well under `MAX_DIFF_LINES=400`. All files are the fix, its test, its task contract, and the mirrored bundle; no unrelated refactor or formatting noise. |
| Readability | One named constant replaces a duplicated literal; the three-line comment names ADR 0002 and its limit. The ERE is compact and readable. |
| Docs | ADR 0002 (already accepted) records the rule; `docs/tasks/task-010.md` records the residual risk (doctor cannot distinguish status/checkbox edits from other task-file edits); the code comment points at the ADR. |
| Contract | `scripts/devloop/doctor.sh` is a contract path; `contract: approved` is declared and the change implements the already-accepted ADR 0002 rather than widening it. |
| Bundle parity | `diff -q scripts/devloop/doctor.sh dist/devloop-skill/assets/scripts/devloop/doctor.sh` -> identical; the suite's "bundle skills mirror the source" assertion passes. |

Extra check on the real state merge: in a detached worktree at 39fe4f7 with the new `doctor.sh` copied in, `bash scripts/devloop/doctor.sh` -> `0 error(s), 2 warning(s)`, exit 0: `OK HEAD is a bookkeeping commit; evidence is verified at 6366aab…`, `OK HEAD is an integration merge`, `OK merge commit has a passing clean gate result`, `OK review file docs/reviews/task-009-r1.md covers the reviewed SHA`, `OK docs/STATE.md verified at HEAD^`. The dirty-tree warning is expected (uncommitted doctor copy); the hooks-not-executable warning is an artefact of the throwaway worktree (local modes only, the repo index stores 100644). The parent `doctor.sh` on the same merge exits 1 with `ERROR no gate result for HEAD` and `ERROR no approving review file covers HEAD` plus a stale-state WARN, which is exactly the reported bug.

## Blockers

None.

## Findings (non-blocking)

1. `tests/run.sh:497-508` — only the HEAD^/diff call site is asserted. The fixture's `docs/STATE.md` carries a foreign `last_verified_sha` (6366aab…), so the second call site (`doctor.sh:186-188`) never takes its OK branch during the suite; a future revert there would only downgrade an OK to a WARN and the tests would stay green. Suggest also asserting `docs/STATE.md verified at HEAD^` for the probe commit, or seeding `last_verified_sha` in the fixture.
2. `scripts/devloop/doctor.sh:105` — the regex is path-based, so any change to `docs/tasks/<name>.md` (new task file, rewritten acceptance text) counts as bookkeeping, not only status/checkboxes. This is inherent to git name-only detection, is documented in `docs/tasks/task-010.md` (Risks), and remains gated by review of the state change; no code change requested in this task.
3. `docs/tasks/task-010.md:20` — AC4 is checked while the task-010 state PR does not exist yet; it can only be demonstrated in that follow-up PR (doctor 0 errors on the state merge). Not blocking the code, but the integrator must actually demonstrate AC4 there rather than inherit the checkbox.

## Verdict rationale

`doctor` now applies ADR 0002 consistently: both the HEAD^ bookkeeping detection and the STATE verification accept `docs/tasks/*.md` without accepting arbitrary paths, while still requiring the parent to be an integration merge with gate and review evidence. The test now exercises STATE plus a task file in one commit and is genuinely red on the parent (117/2) and green here (119/0), and the real state merge 39fe4f7 goes from 2 errors to 0. The change is 64 lines, the bundle mirrors the source, and the contract-path approval is consistent with the accepted ADR.
