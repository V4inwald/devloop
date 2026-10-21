---
task: task-009
sha: b081d065392ef1c89996b18b0e61b65b613afc9f
verdict: approve
blockers: 0
reviewer: reviewer-017
contract: approved
date: 2026-10-21
---

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: the extracted guard `run:` block was executed with a stub `gh` (7 scenarios): legit `Merge pull request #42 …` + `MERGED`/SHA/`main` -> rc 0, no issue; non-PR subject -> rc 1 + 1 issue; wrong mergeCommit -> rc 1 + 1 issue; PR base `release` -> rc 1 + 1 issue; `gh pr view` exit 1/empty -> rc 1 + 1 issue (not an early abort); `state=OPEN` -> rc 1 + 1 issue; all-zero `after` -> rc 0. AC2: `ci.yml:3-8` triggers only `pull_request` + `push: branches: [main]`; no `task/**` anywhere in the file. AC3: `docs/adr/0002-…md` (status accepted, decision + consequences), `AGENTS.md:22-27` exception updated; all task-001..008 have `status: done` and 0 unchecked boxes (`grep -c '- [ ]'` = 0 each). AC4: `.gitignore:15-17` adds `id_ecdsa`, `id_dsa`, `.gh/`; guard/CI/bundle tests pass (119/0). AC5: `bash tests/run.sh` -> passed: 119, failed: 0; `bash scripts/devloop/gate.sh` -> exit 0, `dirty: false`, `ok: true` for b081d06. |
| Tests | `tests/run.sh:680-690` adds 5 assertions (guard PR-mode grep, baseRefName/BASE_BRANCH, CI single trigger, `.githooks` mirror, docs-template mirror). `git diff --numstat 9f056ff b081d06 -- tests/run.sh` = `13 0` (additions only); suite total 114 -> 119 matches README update. |
| Test integrity | No assertion removed or weakened: `git diff 9f056ff b081d06 -- tests/run.sh \| grep '^-'` returns nothing. `bash scripts/devloop/policy.sh --strict 9f056ff` -> 0 violations, 0 warnings; no skips/timeouts/sleeps added. |
| Correctness | Guard logic re-verified against the real HEAD block (`main-guard.yml:50-86`): subject parsed from the merge-commit API (not the raw push), state/oid/base each checked with distinct reasons; `0…0` deletion short-circuit first. Non-default-base and API-failure cases confirmed above. `dist/…/main-guard.yml` is byte-identical to the source (`diff -r` clean). |
| Errors | `gh pr view` failure is explicitly swallowed (`2>/dev/null \|\| true`) and mapped to `cannot read PR #… (unknown PR or API failure)`, then issue + exit 1 — verified. Issue creation is best-effort (`\|\| true`) so a failing issue API still yields a red job. Residual unguarded path noted as a finding (commit-message lookup, `main-guard.yml:50`). |
| Security | No secret/token added; `GH_TOKEN` from `${{ github.token }}`, checkout uses `persist-credentials: false`; issue body built with `printf '%s'` (no injection), title uses the SHA. New ignores reduce accidental credential commits. `contract: approved` since workflows + `AGENTS.md` are contract paths. |
| Compatibility | Local mode cannot false-positive: `grep -qE '^REQUIRE_PR="?true"?'` verified match for `REQUIRE_PR="true"`/`true`, no match for `false`, missing file, and commented line — the guarded step is skipped (`main-guard.yml:35`), while `ci.yml` documents the local-mode task trigger in its comment. Kit bundle mirrors source for workflows, hooks, AGENTS and the five doc templates (`diff -r`/`diff -q` clean). |
| Scope | 272 changed lines (233 insertions + 39 deletions; `git diff --numstat`) < `MAX_DIFF_LINES=400` — the packet's "526" is raw diff-file lines. Changes are confined to the task-009 scope plus the README assertion count; no refactor, no dependency, no formatting noise. |
| Readability | Workflow split into checkout/mode/verify steps with specific failure reasons (`state is …`, `merge commit is …`, `merged into …`); grep and jq are readable; no dead code. |
| Docs | ADR 0002 records the bookkeeping rule and its alternatives; AGENTS §2 references it; workflow header explains detection vs prevention and PR-mode-only behaviour; README count updated to 119; task-006/008 notes are additive and factual (STATE:15-24 records public repo, protection, rejected direct push, merged bookkeeping PR). Task-009 stays `status: review` and is closed by the state PR, as ADR 0002 requires. |

## Blockers

None.

## Findings (non-blocking)

1. `.github/workflows/main-guard.yml:50` — the commit-subject lookup (`gh api … | head -1`) is unguarded under `set -e`/`pipefail`: an API outage or SIGPIPE from `head` aborts with a red job but no audit issue. AC1 only promises the `gh pr view` path, and the token has `contents: read`, so this is residual; mirroring the `|| true` + empty-subject handling would make "issue on every failure path" literally true.
2. `.github/workflows/main-guard.yml:29` — the mode grep accepts `REQUIRE_PR=true` and `REQUIRE_PR="true"` but not `REQUIRE_PR='true'`, which `common.sh` sources as true; such a config would silently skip the guard in a PR-mode repo. The kit template uses double quotes so risk is low, but source-parsing (as `common.sh` does) would remove the divergence. The same regex has no `$` anchor, so `REQUIRE_PR="truey"` matches (harmless, verified).
3. `docs/tasks/task-009.md:28-30` — the "Touched" list omits `README.md` (changed for the 114 -> 119 count) and `dist/` assets (covered only as "refreshed bundle"). Scope description is slightly inaccurate.
4. `tests/run.sh:681-690` — the new guard tests are text greps on the workflow; they would stay green even if the skip or base-branch logic broke. The behaviour is covered here only by the manual stub-`gh` run; an executable test (as done for `policy.sh` refusals) would be stronger.
5. AC4's `.gitignore` additions (`.gh/`, `id_ecdsa`, `id_dsa`) have no test assertion; the AC only claims the guard/CI/bundle tests pass, so this is documentation-vs-test coverage, not a failure.

## Verdict rationale

The guard now runs only in PR mode, creates the audit issue on every documented failure path including an unreadable PR, and rejects merges whose base is not the default branch — all reproduced against the real extracted block with a stub `gh`. CI no longer runs twice per task branch, the ADR/AGENTS/task-status bookkeeping is consistent and factual, and the gate plus 119-test suite cover this SHA with a clean bundle mirror. The remaining items are hardening refinements, not defects that block integration.
