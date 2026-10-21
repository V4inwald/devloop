---
task: task-007
sha: 31c0416307f1c94521f8d0b0e012aca68cf85a79
verdict: approve
blockers: 0
reviewer: reviewer-015
contract: approved
date: 2026-10-21
---
## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: static read of `.github/workflows/main-guard.yml:28-53` plus a stub-`gh` run of the exact `run:` block extracted from the YAML — legit PR merge -> exit 0; fake subject or wrong `mergeCommit.oid` -> issue created + exit 1; all-zero `after` -> exit 0. AC2: `bash tests/run.sh` -> 110 passed, 0 failed, including `tests/run.sh:652-653` (custom install) and `:664` (fresh install). AC3: `scripts/devloop/protect.sh:58-64` maps both real 403 phrases to the three options. AC4: `README.md:89-94`, `design/04-gates-and-review.md:128-133`, `dist/devloop-skill/SKILL.md:185-190`, `AGENTS.md:61-66` all say plan-dependent protection and detection-not-prevention. AC5: gate result `dirty:false ok:true` for the reviewed SHA. |
| Tests | New assertions `tests/run.sh:652-653,664,674-681` ship the two workflows, check the guard strings and mirror `.github/workflows` against `dist/devloop-skill/assets/.github/workflows` (verified separately: `diff -r` -> identical; root `AGENTS.md` vs bundle -> identical). All 110 pass. |
| Test integrity | `git diff HEAD~1 HEAD -- tests/run.sh` has zero removed lines: only additions; no test skipped, no timeout raised, no sleep added. README count updated 102 -> 110 and matches the observed 110. |
| Correctness | The success condition is the exact string `"MERGED $SHA"` (`main-guard.yml:45-46`), so an empty `mergeCommit.oid` or a different SHA cannot match; only digits are extracted from the subject (`:38`); deletion is skipped by the all-zero check (`:30-34`). Verified against a stub `gh`: fake `Merge pull request #42` with a different merge commit -> exit 1; valid merge commit -> exit 0. `protect.sh` captures stderr correctly (`2>&1 >/dev/null`) and the `if ! ERR=...` assignment runs in the current shell. |
| Errors | Normal failure path creates the issue *before* `::error::` and `exit 1` (`main-guard.yml:50-53`). The `gh pr view` failure path is a non-blocking finding below; the job still turns red. |
| Security | No shell injection: the subject only reaches `sed` via stdin and `echo`; `$pr` is `[0-9]+`; issue title/body use the event SHA/actor/before and `printf` arguments, never `eval`. Permissions (`:12-15`) are minimal: `contents: read`, `issues: write`, `pull-requests: read`; no `contents: write`/`actions: write`. Verified the injection probe `Merge pull request #42 from x $(touch /tmp/pwned)` created no file. |
| Compatibility | Installer mapping (`dist/devloop-skill/install.sh:64-66`) sends `ci.yml` to `devloop-ci.yml` and `main-guard.yml` to `devloop-main-guard.yml`; the asset tree has exactly those two workflows and no CODEOWNERS. A pre-existing user `ci.yml` is preserved (asserted at `tests/run.sh:649-651`). Detection is additive: `integrate.sh`/`gate.sh` behavior is unchanged. |
| Scope | 12 files, +223/-17 = 240 changed lines (`git diff --numstat`), under `MAX_DIFF_LINES=400`; packet's 378 is its raw diff-line count, also under the limit. No unrelated refactor, no dependency added, bundle refreshed and mirror-tested. |
| Readability | Workflow comments state the detection contract up front (`main-guard.yml:3-6`); variables and step name are clear. Nit: the 500-character `body=` line (`:50`) and the stale one-workflow header comment in `install.sh:10-11` are hard to scan. |
| Docs | All four hot docs state plan dependence and "detection, not prevention" (`README.md:89-94`, `design/04:128-133`, `SKILL.md:185-190`, `AGENTS.md:61-66`), consistent with the guard comment and `protect.sh` message. AC4 met. |

## Blockers

None.

## Findings (non-blocking)

1. `main-guard.yml:43-44` — `gh pr view` runs under `set -e`; if it fails (fake/nonexistent PR number such as `#99999`, or an API error) the step aborts before the issue is created. Reproduced with the stub: exit 1, `ISSUE_CREATED` count 0. Detection still happens (red job) but the durable report is missing, which is a partial gap against "otherwise opens an issue and fails". Smallest fix: `merged="$(gh pr view ... || true)"` and set `reason="PR lookup failed"` when empty.
2. `main-guard.yml:43` — only `state,mergeCommit` is checked. A merged PR whose base is not `main` (or an old main merge commit force-pushed back) would satisfy both conditions. This assumes main is the only PR base and that push access is not adversarial, which matches the detection threat model, but adding `baseRefName` to the `--json` list and requiring `main` would close it for free.
3. `dist/devloop-skill/install.sh:65` — `devloop-main-guard.yml` is installed unconditionally, while `.devloop.conf.example:14` defaults `REQUIRE_PR="false"` and local mode with `--push` writes a `chore(merge):` commit (`integrate.sh:283-285,323`) that the guard will flag. A default install that keeps local mode will therefore open an issue on the first legitimate integration. Either document "main-guard presumes PR-only `main` (set `REQUIRE_PR=true`)" next to the install output, or install the guard only when PR mode is configured.
4. `tests/run.sh:674-681` — the guard tests are string greps; they would pass if the `sed`/`case` logic were deleted or inverted, and `protect.sh:58-64` has no 403-mapping test. A stub-`gh` test (the technique used in this review) would make the fail path executable. Acceptable for this task because the verification plan explicitly limits the guard to a static read, but it is the weakest evidence in the packet.
5. `main-guard.yml:51` — `gh issue create ... || true` hides why reporting failed (issues disabled, token scope). The job still fails, so nothing is silently approved, but logging the failed creation would keep the cause. Minor.
6. `main-guard.yml:10` — `branches: [main]` is hardcoded while `MAIN_BRANCH` is configurable; a consumer using `master` gets a guard that never runs. The shipped `ci.yml` has the same property, so this is consistent rather than new. Minor.

## Verdict rationale

The change is honest about its limits: every doc states that GitHub Free cannot protect a private branch and that `main-guard` only detects, and the workflow, install mapping and `protect.sh` message agree with that wording. The PR check is robust against the stated attack — a forged `Merge pull request #N` subject only passes when the PR is MERGED and its `mergeCommit.oid` is exactly the pushed SHA, which I confirmed by executing the extracted `run:` block with a stub `gh`. Tests are additive and green (110/0), the gate is clean for the reviewed SHA, and the diff is 240 lines with no weakened assertions. The findings above are hardening and documentation gaps, not blockers for a detection-only control.
