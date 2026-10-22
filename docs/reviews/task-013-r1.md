---
task: task-013
sha: d1d608ddb1cb35b9d2c8b195ca1a1238f1e211ba
verdict: approve
blockers: 0
reviewer: reviewer-022
contract: approved
date: 2026-10-22
---

## Evidence

| Rubric item | Evidence |
|---|---|
| 1 Acceptance (AC1: copy only changed test files, run in base worktree, exit 0/1/2) | Read `scripts/devloop/prove-red.sh`: base validated at :16, detached worktree at :25-31, only `git diff --name-only --diff-filter=ACMR "$BASE...HEAD"` test paths copied at :33-38. Independently reproduced in `/tmp/rv13-prove` (base `tests/*.sh` exit 0, HEAD `test.sh` exit 1 / `ok.sh` exit 0): red case -> `CODE=0`; base-green case -> `CODE=1`; missing command -> `CODE=2`; unknown base -> `CODE=2`; base=HEAD (no changed tests) -> `CODE=2`. `prod.txt` was not copied. |
| 1 Acceptance (AC2: tests cover both directions) | `tests/run.sh:697-712` builds a throwaway repo with the same two cases and asserts `CODE=0` / `CODE=1`. `bash tests/run.sh` -> `passed: 134, failed: 0`, `EXIT:0`, including both new assertions. |
| 1 Acceptance (AC3: docs + stale backup path + exit-4 help) | `dist/devloop-skill/SKILL.md:42` now says `backup-<utc>-<pid>` matching `dist/devloop-skill/install.sh:45`; `install.sh:14` exit-4 help now reads "conflicts or symlinked destinations", matching the two `exit 4` paths at `install.sh:97-101` (symlinks) and `install.sh:117-121` (conflicts). Tool documented at `dist/devloop-skill/SKILL.md:114-115`, `.agents/skills/dev-cycle/SKILL.md:80-82`, `README.md:50`. |
| 1 Acceptance (AC4: tests, gate, doctor, bundle) | `bash scripts/devloop/gate.sh` -> exit 0, `TEST PASS 16s`, `LINT PASS`, result.json `sha` = d1d608d..., `dirty:false`, `ok:true`; `git status --porcelain` clean at gate time. Bundle asset is byte-identical to source (`diff -q scripts/devloop/prove-red.sh dist/devloop-skill/assets/scripts/devloop/prove-red.sh` -> no output) and dev-cycle SKILL mirror matches (`diff` of both blobs -> identical). `doctor.sh` reports no review for HEAD only because the review is written after the commit; after writing this file it reports no error. |
| 2 Tests | `tests/run.sh:697-712` exercises the real script end-to-end; the assertions would fail without prove-red.sh (`bash: <path>: No such file` -> 127, neither 0 nor 1 -> `ko`), and `git cat-file -e b9d2fd9:scripts/devloop/prove-red.sh` -> `ABSENT_AT_BASE`. The test is not tautological: an always-exit-0 script would fail the red assertion, an always-exit-1 would fail the green one. Independently replicated both with a fresh repo and got 0/1. |
| 3 Test integrity | `git diff --numstat b9d2fd9..d1d608d -- tests/run.sh` -> `17 0 tests/run.sh`: additions only, no deleted or loosened assertion, no skip, no sleep, no timeout change, no `\|\| true` added around an assertion. Full diff has 3 deletions total, all doc wording (`README.md` count 132->134, `SKILL.md` backup path, `install.sh` help line). |
| 4 Correctness | Base is checked out detached (`git worktree add -q --detach`), files copied from `HEAD:$f` into the worktree only, command executed with cwd = worktree (`( cd "$WT" && "$@" )`), exit 0 only on command failure, 1 on pass, 2 on usage/no test; `head -1` redirect uses `"$BASE^{commit}"` validation so a branch or sha both work. Edge cases verified: path containing a space (`tests/sp ace/t.sh`) copied and run correctly (`CODE=0`); no-dashdash form (`prove-red.sh HEAD^ true`) still parses -> `CODE=1`. |
| 5 Errors | Every failure path exits with a distinct code and a message on stderr: usage (:12,15), unknown base (:16), no changed tests (:23), worktree add failure (:31), pass-on-base (:41). Cleanup is a `trap cleanup EXIT` (:30) so usage errors after registration and command failures both clean up; verified `git worktree list` after both cases shows only the main worktree, `ls -d /tmp/devloop-prove-red.*` -> none. No output is captured or swallowed except `git worktree remove` guarded by `|| true`, which is correct on re-entry. |
| 6 Security | No `eval`, no unquoted expansion of paths; `git show "HEAD:$f" > "$WT/$f"`, `mkdir -p "$WT/$(dirname "$f")"` and the `"$@"` invocation are quoted. `$FILES` comes from `git diff --name-only`, which is repository-relative and cannot emit absolute or `..` paths, so no traversal outside the temp worktree. No secrets, tokens or user data in code, tests or logs. |
| 7 Compatibility | Additive tool; no existing script, hook, config key or exit-code contract changed. New exit codes (0/1/2) are documented in the script header and README; no DB/format/API change. |
| 8 Scope | `git diff --stat b9d2fd9..d1d608d` -> 9 files, 163 insertions / 3 deletions (264 raw diff lines, < `MAX_DIFF_LINES=400`). Files are exactly the task scope plus the task file and bundle refresh; no unrelated refactor, no new dependency, no formatting noise. |
| 9 Readability | 44-line script, single-purpose functions, header comment states usage and exit contract; copy, run and cleanup phases are visually separated (:19-23, :25-31, :33-44). Names `BASE`, `WT`, `FILES` are clear in context. No comment needed beyond the header. |
| 10 Docs | Tool is described in the gate step of both SKILL copies and the README script table, with the exact command form and semantics (expects failure at base). The two stale task-012 review items (backup path, exit-4 help) are corrected at the source of truth and in the distributed SKILL. The known limitation (base worktree lacks untracked deps, so a command can fail for the wrong reason) is recorded in `docs/tasks/task-013.md` Risks. |

## Blockers

None.

## Findings (non-blocking)

1. `prove-red.sh:40-43` — any non-zero status counts as "red", including interpreter errors, missing dependencies or syntax errors in the copied test, not only failed assertions. This is inherent to the approach and partly covered by the task Risks; a one-line note in `dist/devloop-skill/SKILL.md` would help future users interpret a misleading red.
2. `prove-red.sh:21-22` — test detection is a filename heuristic (`tests?/`, `specs?/`, `__tests__/`, `*.test.*`, `*.spec.*`); a root-level test such as `test_parser.py` is not detected and the tool exits 2 with "no changed test files". Acceptable for this repository (all tests under `tests/`), worth documenting if the kit is reused elsewhere.
3. `dist/devloop-skill/SKILL.md:42` — the backup path omits the `-<n>` collision suffix that `install.sh:48` appends when the directory already exists. Cosmetic; the raw directory still matches the documented prefix.
4. `prove-red.sh:21-23` — a failure of `git diff` would be swallowed by `|| true` and reported as "no changed test files" (exit 2) rather than an error. The base is validated just before, so impact is low.

## Verdict rationale

`prove-red.sh` is a real regression guard: it checks out the base detached, copies only the changed test paths, runs the command in that worktree, and cleans up on every exit; I reproduced the red (exit 0), green (exit 1) and usage/no-test (exit 2) paths independently and confirmed the main tree and worktree list stayed untouched. The tests cover both directions and would fail without the script, with no assertion weakened (17 added lines, 0 removed). Documentation matches the implementation — the corrected installer backup path and exit-4 help are accurate — and the bundle mirrors the source, so this is safe to approve.
