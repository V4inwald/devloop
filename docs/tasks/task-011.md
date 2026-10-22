---
id: task-011
status: review
branch: task/011-guard-script
created: 2026-10-22
owner: lead
implementer: lead
---

# Guard testable : logique dans un script, chemins d'échec couverts

## Outcome

The `main-guard` logic lives in `scripts/devloop/main-guard.sh`, wraps the commit lookup (an API
failure still opens the issue), accepts single-quoted `REQUIRE_PR='true'`, and is covered by
stub-`gh` tests for the legitimate path, wrong merge commit, wrong base, API failure and branch
deletion.

## Acceptance criteria

- [x] AC1: the workflow delegates to `scripts/devloop/main-guard.sh`; the mode step accepts `"true"`, `'true'` and `true` with an anchored pattern.
- [x] AC2: the script creates the issue on every failure path, including an unreadable commit or PR, and still exits 1; it verifies state, mergeCommit and baseRefName.
- [x] AC3: `tests/run.sh` exercises the real script with a stub `gh`: legit -> 0/no issue, wrong oid -> 1/issue, wrong base -> 1/issue, API failure -> 1/issue, all-zero -> 0/no issue.
- [x] AC4: tests, gate and doctor pass; the bundle is refreshed.

## Scope

Touched: `scripts/devloop/main-guard.sh`, `.github/workflows/main-guard.yml`, `tests/run.sh`,
`docs/tasks/task-011.md`, refreshed bundle.

## Verification plan

1. `bash tests/run.sh` (>= 124 assertions).
2. `bash scripts/devloop/gate.sh`.
3. PR merge under protection; `main-guard` runs on the merge and stays green.

## Risks

- The guard remains detection; a direct push that edits the script or the conf can blind it.
- The stub tests model the `gh` contract; a real API shape change still needs the CI run.
