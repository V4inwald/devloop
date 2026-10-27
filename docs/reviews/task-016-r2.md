---
task: task-016
sha: 13669dcf9c22a8dfc1895bf33ea2ca37d748d327
verdict: approve
blockers: 0
reviewer: reviewer-016
contract: approved
date: 2026-10-27
---

# Review — task-016 round 2

Independent re-review of `13669dcf9c22a8dfc1895bf33ea2ca37d748d327` (`task/016-harness-check`,
base `311e4e36`), which fixes the single blocker of `docs/reviews/task-016-r1.md`. Delta
`e9ab9a9..13669dcf`: two script copies +10/−6, task file +2 (AC8), plus the committed r1 review.
Change size: 325 insertions, 2 deletions = 327 changed lines, under `MAX_DIFF_LINES=400`
(`.devloop.conf:7`).

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `bash scripts/devloop/harness-check.sh` → `harness-check: OK (3 skills, AGENTS.md 128 lines)`, rc 0. AC2 regression: my independent fixtures `/tmp/rv016b/{orphan,braces,phantom,long,none}` still rc 1 each with the expected `FAIL:` lines (`skill 'beta' is not named verbatim`, `template syntax at line 1`, `named script 'scripts/devloop/phantom-777.sh' does not exist`, `AGENTS.md has 160 lines (limit 150)`, `AGENTS.md missing at …`). AC3: `bash tests/run.sh` → `passed: 141, failed: 0` (same 7 `ok` harness-check lines as r1). AC4: `.devloop.conf:3` CHECK_LINT includes the script; `.git/devloop/gate/13669dcf…/result.json` → `"sha": "13669dcf…"`, `"ok": true`, `"dirty": false`, LINT exit 0, TEST exit 0 (15 s). AC5: `diff -u` of the two copies → identical; both blobs `2a71622` in `git ls-tree HEAD`. AC6: `README.md:65` 141 assertions, `README.md:71` "Adoption opt-in : l'ajouter à `CHECK_LINT`". AC8: `timeout 3 bash scripts/devloop/harness-check.sh --root` → rc 2 immediately, `usage: harness-check.sh [--root <dir>] [-q]` on stderr (no 124); `--root ""` → rc 2; `--root .` → rc 0. |
| Tests | No new automated test for the arg guard (AC8 is a manual criterion; `tests/run.sh` is byte-identical to r1, blob `7bfad5a`), so the fix is proven only by the commands above — recorded as a non-blocking finding. The existing five refusal cases still exercise the real script, and I re-ran them independently. |
| Test integrity | `git diff main..HEAD -- tests/` → `28 0 tests/run.sh`; removed lines in the tests diff = 0; blob unchanged between r1 and r2; assertion count still 141, none skipped, no timeout/sleep change. |
| Correctness | Fix 1: `scripts/devloop/harness-check.sh:21-25` guards `[ $# -ge 2 ]` before `shift 2` and exits 2 with the usage string. Fix 2: `:51` uses a bounded regex `(^|[^[:alnum:]_-])${name}([^[:alnum:]_-]\|$)`; verified a skill dir `dev` with `AGENTS.md` containing only `devloop` → rc 1, while an exact `dev` token → rc 0. Fix 3: `:74` counts with `awk 'END { print NR }'`; a 160-line `AGENTS.md` with no trailing newline measures `wc -l`=159 but `awk`=160 and the checker now fails (161 reported after a prepended header line, i.e. the unterminated record is counted). Kit still passes: no false positive (3 skills, 128 lines). One residual edge: `${name}` is interpolated into the ERE unescaped (`a.b` matches `aXb` → rc 0); fail-open only for regex-metachar skill names, see findings. |
| Errors | `--root` without value now exits 2 immediately (the r1 infinite loop is gone; rc 124 no longer reproducible). `--root ""` → rc 2, nonexistent root → rc 2, unknown flag → rc 2; missing `AGENTS.md` → `FAIL` + rc 1; a bad skill-name regex makes `grep` exit 2 and `\|\| fail` fail closed (noisy but safe). `set -uo pipefail` retained; no `-e`, so the `\|\| fail` accumulator still works. |
| Security | Trusted local input only (repo files); all expansions quoted; no secret in `git diff main..HEAD` (the only `secret` hits are prose inside the committed r1 review). Rule 3 still only `-f`-tests `"$ROOT/$rel"` (existence, no read/exec). Residual regex interpolation of the skill directory name is fail-open but requires a committed metachar-named skill dir — non-blocking. |
| Compatibility | Additive script; the kit ships no `dist/devloop-skill/assets/.devloop.conf` and `dist/devloop-skill/SKILL.md:43` says it never overwrites `.devloop.conf`, so installed repositories do not inherit the check → the opt-in claim holds. `bash -n` green. No public API/DB/format change. |
| Scope | 7 files: the 6 task-scope files plus `docs/reviews/task-016-r1.md` (added by commit `a75d749`, the required review handoff, tolerated as `A docs/reviews/`). `AGENTS.md`, `.agents/skills/**`, kit version and `dist/devloop-skill/SKILL.md` untouched. |
| Readability | 84 lines, one comment block per rule, `fail()` accumulator, `-q` for tests; the arity guard is self-explanatory. No maintainability issue. |
| Docs | `docs/tasks/task-016.md:29-30` adds AC8 referencing the r1 blocker; README keeps the real count and the opt-in; r1 review committed as history. Future agents can reconstruct why the cap is code-resident and why adoption is opt-in (`docs/tasks/task-016.md:53-58`). |
| Portability (macOS bash 3.2) | No GNU-only construct: `grep -qE/-nE/-ohE/-rhoE`, `sort -u`, `awk`, `printf`, `basename`, `$(( ))`; process substitution is bash-builtin and the script is invoked with `bash`. ASSUMED: not executed on macOS (host bash 5.2); basis = POSIX/BSD-documented flags and constructs predating bash 3.2. |
| Contract | `.devloop.conf` is a contract path and the diff only *adds* a check to `CHECK_LINT`; `MAX_DIFF_LINES=400` and `REQUIRE_PR=true` unchanged, no check removed or relaxed, `scripts/devloop/gate.sh` untouched → the loop is stricter, not weaker: `contract: approved`. |

## Blockers

None. The r1 blocker (`scripts/devloop/harness-check.sh:21`) is fixed and independently reproduced:
`timeout 3 bash scripts/devloop/harness-check.sh --root` → rc 2 with the usage message, and the
three follow-on findings were addressed and verified (`:51` token match, `:74` `awk` line count).

## Findings (non-blocking)

- `scripts/devloop/harness-check.sh:51` — `${name}` is interpolated into `grep -E` without escaping:
  a skill directory named `a.b` matches `aXb`, and a name with `(`/`[` makes the regex invalid
  (`grep` exits 2, `|| fail` fails closed). Escape the name (`sed 's/[][\\.*^$/]/\\&/g'`) or match
  with `grep -qF` then check the boundary characters. No impact on the kit's 3 skills.
- `tests/run.sh:842-868` — the `--root` arity guard has no automated regression test (AC8 is manual
  only); a one-line `expect_rc`-style check would prevent the hang from coming back.
- `docs/tasks/task-016.md:20-30` — acceptance checkboxes still unchecked, expected at review time;
  the integrator flips them with `status: done`.

## Verdict rationale

All acceptance criteria, including the new AC8, are met with commands I ran myself: the gate
artifact for exactly this SHA is clean and green, the suite is 141/0 with tests unchanged since r1,
the mirror blobs are identical, and the three defects from round 1 are fixed without weakening
either the rules or the loop. `contract: approved` because `.devloop.conf` gains a check and loses
nothing. The remaining points are bounded edge cases (regex metacharacters in a skill directory
name, one missing unit-level regression) that do not affect the kit or the gate; they can be
follow-ups without reopening this task.
