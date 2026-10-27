---
task: task-016
sha: e9ab9a9f2a2dfefdf5cadbafe86b3deb0c124b5f
verdict: revise
blockers: 1
reviewer: reviewer-016
contract: approved
date: 2026-10-27
---

# Review — task-016 round 1

Independent review of `e9ab9a9f2a2dfefdf5cadbafe86b3deb0c124b5f` (`task/016-harness-check`, base
`311e4e36`). Change size: 250 insertions, 2 deletions, 6 files (`git diff --numstat main..HEAD`) —
252 changed lines, under `MAX_DIFF_LINES=400` (`.devloop.conf:7`).

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `bash scripts/devloop/harness-check.sh` → `harness-check: OK (3 skills, AGENTS.md 128 lines)`, rc 0. AC2: own fixtures in `/tmp/rv016/{orphan,braces,phantom,long,none}` (not the tests' fixtures): rc 1 each, with `FAIL: skill 'beta' is not named verbatim in AGENTS.md`, `FAIL: AGENTS.md has template syntax at line 2`, `FAIL: named script 'scripts/devloop/phantom-777.sh' does not exist`, `FAIL: AGENTS.md has 160 lines (limit 150)`, `FAIL: AGENTS.md missing at /tmp/rv016/none/AGENTS.md`; positive control `/tmp/rv016/good` rc 0. AC3: `bash tests/run.sh` → `passed: 141, failed: 0`. AC4: `.devloop.conf:3` CHECK_LINT runs the script; `.git/devloop/gate/e9ab9a9.../result.json` → `"sha": "e9ab9a9f..."`, `"ok": true`, `"dirty": false`, LINT exit 0, TEST exit 0 (16 s). AC5: `diff -u scripts/devloop/harness-check.sh dist/devloop-skill/assets/scripts/devloop/harness-check.sh` → identical; both blobs `21e91d3` in `git ls-tree HEAD`. AC6: `README.md:65` says 141 assertions, `README.md:69-71` lists the 4 checks and "Adoption opt-in : l'ajouter à `CHECK_LINT`". |
| Tests | `tests/run.sh:842-868` adds the five failure fixtures plus two passing controls (`tests/run.sh:851` runs the checker on the kit itself); they invoke the real script, not a stub, so they fail if the rules regress. I rebuilt the same five cases independently and got the same rc 1 / clear FAIL. |
| Test integrity | `git diff --numstat main..HEAD -- tests/` → `28 0 tests/run.sh`: additions only, no assertion deleted or weakened, no skip, no sleep, no timeout raised. Assertion delta 134 → 141 matches the 7 new `expect_*` calls (`tests/run.sh:851-868`) and matches the suite output. |
| Correctness | Four rules implemented as specified: rule 1 iterates `.agents/skills/*/` and requires each name in `AGENTS.md`; rule 2 reports template-syntax line numbers; rule 3 collects `scripts/**.sh` from `AGENTS.md` + skills and `-f`-tests each; rule 4 caps at 150 hard-coded in the script (task note 53-54: a branch cannot raise it without touching the script). No false positive on the kit: rc 0 with 3 skills / 128 lines. Argument-error path is broken (see blocker). |
| Errors | Blocker: `scripts/devloop/harness-check.sh:21` — `--root` with no value hangs (verified `timeout 3 bash scripts/devloop/harness-check.sh --root` → rc 124, no output), while the header documents exit 2 for usage errors. Other paths are handled: missing root dir → rc 2; unknown flag → rc 2; missing `AGENTS.md` → `FAIL` + rc 1; `grep` non-matches neutralised with `\|\| true` / `\|\| fail`; `set -uo pipefail` present (no `-e`, deliberate for failure accumulation). |
| Security | No untrusted input boundary beyond local files; all expansions quoted (`"$ROOT"`, `"$AGENTS"`, `"$dir"`, `"$rel"`), `grep -qF --` guards pattern injection. `git diff main..HEAD \| grep -nEi "api[_-]?key\|secret\|token\|password\|private"` → no match. Rule 3 builds `"$ROOT/$rel"` from an `AGENTS.md`-derived `scripts/...` match and only performs an existence test, never reads or executes the target, so a crafted `..` segment leaks at most file existence, not content. |
| Compatibility | Additive script; no shipped example is rewired: the kit has no `dist/devloop-skill/assets/.devloop.conf`, and `dist/devloop-skill/SKILL.md:43` states the kit never overwrites `.devloop.conf`, so installed repositories do not inherit the check → the README "opt-in" claim is accurate. `bash -n` reports no syntax error; no public API/DB/format change. |
| Scope | 6 changed files, exactly the task scope list (`docs/tasks/task-016.md:32-33`): the two script copies, `.devloop.conf`, `tests/run.sh`, `README.md`, the task file. `AGENTS.md`, `.agents/skills/**`, kit version and `dist/devloop-skill/SKILL.md` untouched. |
| Readability | 80 lines, commented per rule, `fail()` accumulator, `-q` for tests; maintainable as-is. |
| Docs | `README.md:65-71` states the real count and the opt-in; `docs/tasks/task-016.md:51-57` records the three decisions (cap in script, opt-in adoption, pure Bash). `AGENTS.md` already documents the review contract, so leaving it untouched is correct. |
| Portability (macOS bash 3.2) | No GNU-only construct: `grep -qF/-nE/-ohE/-rhoE`, `sort -u`, `wc -l`, `tr -d '[:space:]'`, `printf`, `basename`, `$(( ))` are BSD-compatible; process substitution `done < <(...)` is supported by bash 2+ (so 3.2), and the script is invoked via `bash`, never `sh`. ASSUMED: not executed on macOS (only bash 5.2 here); basis = flags are POSIX/BSD-documented and all constructs predate bash 3.2. |
| Contract | `.devloop.conf` is a contract path. The diff only *adds* a check to `CHECK_LINT` (stricter); `MAX_DIFF_LINES=400` and `REQUIRE_PR=true` unchanged, no check removed, `scripts/devloop/gate.sh` untouched → the loop is not weakened, so `contract: approved`. |

## Blockers

1. `scripts/devloop/harness-check.sh:21` — `--root) ROOT="${2:-}"; shift 2 ;;`: invoking
   `harness-check.sh --root` (flag without value) makes `shift 2` fail without changing `$#`;
   the `while [ $# -gt 0 ]` loop then spins forever with no output and no exit. Reproduced:
   `timeout 3 bash scripts/devloop/harness-check.sh --root` → rc 124. This contradicts the
   script's own header ("Exit: … 2 usage or configuration error"). Required fix: guard the
   arity before shifting, e.g.
   `--root) [ $# -ge 2 ] || { printf 'usage: harness-check.sh [--root <dir>] [-q]\n' >&2; exit 2; }; ROOT="$2"; shift 2 ;;`
   (adding `-e` to `set` would also abort, but the explicit guard is the smallest change).

## Findings (non-blocking)

- `scripts/devloop/harness-check.sh:48` — `grep -qF -- "$name" "$AGENTS"` is a substring test: a
  skill directory named `dev` would be satisfied by the text `devloop`. If "verbatim" is meant
  strictly, match a token/word boundary. No impact on this repo (3 skills, all named).
- `scripts/devloop/harness-check.sh:70` — `wc -l` counts newlines: a 160-line `AGENTS.md` without
  a trailing newline is reported as 159 (verified: a one-line file with no final newline reports
  `0`). `awk 'END{print NR}'` would count records instead.
- `docs/tasks/task-016.md:20-28` — acceptance checkboxes are still unchecked; that is expected at
  review time (the integrator flips `status: done` and the boxes after the review), not a defect.

## Verdict rationale

Every acceptance criterion is met with reproducible evidence: gate result for this exact SHA is
clean and green, the suite is 141/0, the five refusal cases work on fixtures I built myself, the
mirror is byte-identical, and the `.devloop.conf` contract change makes the loop stricter rather
than weaker. The single blocker is a real defect in the new CLI surface: a documented usage error
turns into an infinite loop; it is reachable only by manual misuse (the gate calls the script with
no arguments), which is why the rest of the change is approved in substance. Fix the
`--root` arity guard (one line, plus an `expect_fail`-style regression check if the author wants
one) and round 2 can approve this SHA's successor with `contract: approved`.
