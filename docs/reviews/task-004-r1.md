---
task: task-004
sha: a7c70993ce25c34acfd3b30cffaecaa3ae114a45
verdict: approve
blockers: 0
reviewer: reviewer-010
contract: approved
date: 2026-10-21
---
## Evidence
| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `.githooks/pre-push:12-13` no longer sources `.devloop.conf`; test `pre-push ignores a repo-local ALLOW_MAIN_PUSH` passes, env override still passes. AC2: `/tmp` probe on a repo with a conflicting hook -> exit 4; `--force` -> exit 0 with `backup-*` under git-common-dir and unknown `pre-commit`/`deploy.sh` intact; fresh install test asserts neutral STATE/LESSONS and `core.hooksPath=.githooks`. AC3: `.github/workflows/ci.yml:3-7,16,18-20,26-28` (main + `task/**`, `timeout-minutes: 20`, checkout@v7 `persist-credentials: false`, step-level env only); `policy.sh --strict main` -> 0 violations. AC4: `git ls-files dist \| wc -l` = 23, `git check-ignore` exit 1; every mirrored path `diff -r` identical. AC5: `bash tests/run.sh` -> 90 passed, 0 failed; `bash scripts/devloop/gate.sh` -> exit 0, `result.json` sha a7c7099…, `ok=true`, `dirty=false`. |
| Tests | `tests/run.sh:605-607` adds the repo-local `ALLOW_MAIN_PUSH` case and `tests/run.sh:618-668` the install-safety/fresh-install cases. Negative control: archived HEAD to /tmp, replaced only `.githooks/pre-push` with `main`'s version, ran the suite -> `89 passed, 1 failed` (`pre-push ignores a repo-local ALLOW_MAIN_PUSH`), so the regression test fails without the hook change. |
| Test integrity | `git diff main...HEAD --numstat -- tests/run.sh` = 54 insertions, 0 deletions; no deleted assertions, no `skip`/`sleep`/raised timeouts in the added lines. Existing assertions untouched. |
| Correctness | Protected branches are built as `main master` plus env/git-config only (`pre-push:12`), so a checked-out `.devloop.conf` cannot grant the unlock; non-fast-forward check retained (`pre-push:29-34`). Installer conflict preflight (`install.sh:74-89`) returns 4 before writing; `--force` backs up only files it replaces (`install.sh:91-96,116`) and only enumerates `assets/` targets, so unknown hooks/scripts survive. CI base selection handles PR, push and zero-SHA new branches (`ci.yml:31-34`). |
| Errors | Installer exits 2/3/4 with actionable messages (`install.sh:20,47-50,84-88`); hook exits 1 with an explicit "`--no-verify` still bypasses; use server-side protection" warning (`pre-push:4-7,22-24`); gate artifacts are uploaded `if: always()` (`ci.yml:38-43`). |
| Security | `git grep -I` over `dist/` for key/token/private-key patterns hit only documentation prose and `policy.sh`'s own detection regex; no credential material. Installer targets come from a fixed `find` under bundled assets (no user-supplied path), backup stays inside `<git-common-dir>`, and CI uses `permissions: contents: read` + `persist-credentials: false`. |
| Compatibility | No public API/format change. The installer adds `devloop-ci.yml` instead of replacing an existing `ci.yml` (`install.sh:64`), and never overwrites STATE/LESSONS/`.devloop.conf` (`install.sh:72,139-146`). One config-surface note below (`PROTECTED_BRANCHES`). |
| Scope | `git diff --stat main...HEAD` = 29 files, 2020 insertions / 12 deletions; 1851 lines are the previously excluded generated bundle, authorized and recorded in `docs/tasks/task-004.md` (Risks/Notes); the hand-written remainder (~169 lines) is inside `MAX_DIFF_LINES=400`. No unrelated refactor, no dependency added, no evidence files touched. |
| Readability | Hook comments explain why `.devloop.conf` is ignored (`pre-push:4-7,24`); installer maps asset -> destination in one table (`install.sh:55-69`) and documents exit codes in its header (`install.sh:13-14`). |
| Docs | `docs/tasks/task-004.md` records the `.git/info/exclude` decision, the generated bundle exception and the post-merge CI risk; `docs/STATE.template.md:4` and `docs/LESSONS.template.md:1-6` are neutral templates covered by the fresh-install test. Missing migration note for `PROTECTED_BRANCHES` is noted below (docs alignment is task-005 scope). |

## Blockers
None.

## Findings (non-blocking)
1. `.devloop.conf.example:12` still advertises `PROTECTED_BRANCHES="main master"` as configuration, but `pre-push` now ignores the file (`.githooks/pre-push:12`) and only reads the environment or `git config devloop.protectedBranches`. A repository that added extra protected branches there silently loses them (main/master remain protected). Documentation alignment is explicitly task-005, but a one-line comment in the example would prevent the surprise.
2. `dist/devloop-skill/install.sh:44-45` names the backup directory with one-second resolution; two `--force` runs inside the same second would share a directory and the later `cp -a` could overwrite the earlier backup entries. Low likelihood; `mktemp -d` would remove it.
3. `dist/devloop-skill/install.sh:149` chmods every `.githooks/*` and `scripts/devloop/*.sh`, including unknown user files whose contents the tests prove are preserved. Harmless today, but "preserve unknown files" holds for content only.
4. `.github/workflows/ci.yml:33` falls back to `HEAD~1` when a branch has no `before` SHA, so the first push of a multi-commit task branch only policies the last commit. Pull requests use `base.sha` and cover the full range; acceptable while PR mode is the merge path (task-006).
5. `dist/devloop-skill/install.sh:117` uses `cp -a` onto an existing destination; with a checked-out symlink at a target path and `--force`, `cp` follows the link rather than replacing it. Refusing symlink targets (or `cp --remove-destination`) would keep all writes inside the repository. Nitpick, not required by this task.

## Verdict rationale
The redesign closes the actual hole: push protection no longer reads a branch-controlled config file, extra protected branches come from the environment or local git config, and the regression test demonstrably fails against the old hook. The 23-file, 1851-line bundle import is a generated artifact, byte-identical to its sources for every mirrored path and authorized in the task file; the installer keeps replaced targets under `<git-common-dir>/devloop/backup-*` and provably leaves unknown files in place. Local evidence (90/0 tests, clean gate for this SHA) is solid, while the CI workflow itself can only be validated by the post-merge GitHub run, as the task already records.
