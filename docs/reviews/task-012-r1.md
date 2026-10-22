---
task: task-012
sha: da5302b6e70f71f84dc7bf1ca777bafe424ba5d3
verdict: approve
blockers: 0
reviewer: reviewer-020
contract: n/a
date: 2026-10-22
---

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `dist/devloop-skill/install.sh:45-50` builds `backup-$STAMP-$$` then `-$n`; a manual fresh + `--force` run produced `backup-20261022T204406Z-869474` and `backup-20261022T204407Z-869697`. AC2 (intent: kit-only chmod): `install.sh:181-187`; manual modes: custom hook 644, custom `deploy.sh` 644, kit hook 751. AC3: `install.sh:80-102`; symlinked `scripts/devloop` -> exit 4, outside dir empty, no `.git/devloop`; symlinked parent `scripts` -> exit 4; `AGENTS.devloop.md` special-cased at `:96`. AC4: gate PASSED (`result.json` ok/dirty false); the bundle is the installer itself — `find . -name install.sh` returns only `dist/devloop-skill/install.sh`; `doctor.sh` exits 1 only for the missing review file this review supplies (plus a stale-STATE warning). Note: AC2's text names `.githooks/commit-msg`, a kit-owned path that is overwritten; the test uses `pre-commit` — see finding 2. |
| Tests | `bash tests/run.sh` -> `passed: 131, failed: 0`; 6 new assertions (`tests/run.sh:656-664,680-692`). Differential against parent `99d9ed0`: parent install sets custom `pre-commit`/`deploy.sh` to 755 (new chmod assertions fail), and a symlinked `scripts/devloop` exits 0 while writing 9 files into the outside dir (new symlink assertions fail); the backup assertion passes on the parent in 5/8 trials (finding 1). |
| Test integrity | `git diff HEAD~1 HEAD --numstat -- tests/run.sh` = 21 added, 0 deleted; total 131 vs 125 before, exactly the six new assertions; no skip, sleep, timeout, or assertion deletion. |
| Correctness | Backup loop increments `n` until a free path (`:47-50`), so it cannot spin on an existing directory and terminates on the first free name. `unsafe_dest` (`:80-89`) checks the final component and every parent up to `.`; `scripts/devloop/*.sh` are caught at the `scripts/devloop` parent and a symlinked `scripts` at `scripts`. The preflight (`:91-102`) runs before the first write at `:148`, and `set -e` is not tripped because the call sits in an `if`. The chmod loop iterates `targets()` only. |
| Errors | Refusal prints each offending path to stderr and exits 4 before any `mkdir`/`cp`; `backup()` skips absent paths. New: removing `... 2>/dev/null \|\| true` means a chmod failure now aborts the installer (fail-loud, but a partial tree exits nonzero); untested. A dangling `AGENTS.md`/`.devloop.conf` symlink is refused by GNU cp (`not writing through dangling symlink`, exit 1), not by the preflight (finding 4). |
| Security | Verified: symlinked `scripts/devloop` and symlinked parent `scripts` both exit 4 with the outside dir empty and no backup store created; no path traversal, no secret, no eval. Hard links and `.devloop.conf`/`AGENTS.md` are outside the preflight but no write escape was observed on GNU coreutils (finding 4). |
| Compatibility | No public interface/DB/format change; installer behaviour is documented in `docs/tasks/task-012.md:33-35` (symlink refusal intentional). Existing installations with a symlinked `.githooks`/`scripts/devloop` now exit 4 instead of writing through it — intentional, reversible by removing the link. |
| Scope | `git diff HEAD~1 HEAD --numstat` = 101 added + 3 deleted = 104 changed lines, 4 files, under `MAX_DIFF_LINES=400` (`scripts/devloop/common.sh`); the packet's 164 is raw diff-with-context. `README.md:64` assertion count 125 -> 131 is bookkeeping outside the declared Scope (finding 6). No dependency or unrelated refactor. |
| Readability | Named `unsafe_dest`, `UNSAFE`, and comments explaining why symlinks are refused and why the chmod set is restricted; the preflight is a self-contained block. No naming/structure defect. |
| Docs | Task outcome, scope, risks and verification plan recorded; installer header and exit-code help are stale (`backup-<utc>`, exit 4 = conflicts only) and `dist/devloop-skill/SKILL.md:42` still shows the old backup name (finding 3); AC2 wording mismatch (finding 2). |

## Blockers

None.

## Findings (non-blocking)

1. `tests/run.sh:660-664` — the backup assertion is wall-clock dependent: it only sees a difference if the two forced installs land in different UTC seconds. Against the parent installer (`99d9ed0`) I measured 5/8 trials where the count still increased, i.e. the new test would pass without the PID/collision change. Smallest fix: assert the basename matches `^backup-[0-9]{8}T[0-9]{6}Z-[0-9]+(-[0-9]+)?$` (deterministically fails the old `backup-<utc>` name) in addition to the count check.
2. `docs/tasks/task-012.md:22` — AC2 says a custom `.githooks/commit-msg` keeps 644, but `commit-msg` is a kit asset and `--force` replaces it (ends 751); the test correctly asserts the non-kit `pre-commit` at `tests/run.sh:657`. The acceptance text and the verified behaviour disagree; correct the AC wording to `pre-commit` (the intended guarantee is "hooks the kit does not ship keep their mode").
3. `dist/devloop-skill/install.sh:5-6` and `dist/devloop-skill/SKILL.md:42` still document `backup-<utc>` without the PID/collision suffix; `install.sh:13-14` still describes exit 4 as conflicts only, though it now also covers symlink refusal. Docs only.
4. `dist/devloop-skill/install.sh:91-102` — the preflight covers `targets()` plus `AGENTS.devloop.md`, but not the `.devloop.conf`/`AGENTS.md` write paths. On GNU coreutils `cp -a` refuses a dangling destination symlink (`cp: not writing through dangling symlink`, exit 1), so I found no escape; the failure is a partial install with exit 1 instead of the clean exit 4. Worth covering if macOS/BSD is supported.
5. `tests/run.sh:680-692` — the symlink test covers `scripts/devloop`, not the `AGENTS.devloop.md` case that AC3 names explicitly; `install.sh:96` implements it but no assertion locks it.
6. `README.md:64` — the 125 -> 131 assertion-count update is outside the task's declared Scope; harmless bookkeeping.

## Verdict rationale

The three holes are closed: the backup path now carries the PID and a termination-safe collision loop, chmod is limited to kit destinations, and symlinked destinations — including a symlinked parent and `AGENTS.devloop.md` — exit 4 before any write. Fresh installs and normal `--force` installs still succeed, and the chmod/symlink regression tests fail deterministically against the parent. The backup regression test is only probabilistic, and the AC2 wording and backup docs are stale; both are non-blocking and easy follow-ups.
