---
id: task-003
status: review
branch: task/003-ci-isolation
created: 2026-10-21
owner: lead
implementer: lead
---

# CI : isoler le store d'artefacts des fixtures

## Outcome

`bash tests/run.sh` passes identically locally and in CI, even when the caller
exports `DEVLOOP_ARTIFACTS` for the top-level gate.

## Acceptance criteria

- [x] AC1: with `DEVLOOP_ARTIFACTS=/tmp/global`, `bash tests/run.sh` -> 68/0.
- [x] AC2: `bash scripts/devloop/gate.sh` -> exit 0, `dirty:false`.
- [x] AC3: the CI failure mode is reproduced locally with `DEVLOOP_ARTIFACTS=/tmp/global` (53 passed / 15 failed before the fix, 68/0 after). The post-merge GitHub Actions run is verified and recorded in STATE after the push; it is not a pre-merge criterion.

## Scope

Touched: `tests/run.sh`, `docs/tasks/task-003.md`.

Out of scope: the CI workflow itself, the integration engine, docs.

## Verification plan

1. `DEVLOOP_ARTIFACTS=/tmp/global bash tests/run.sh`
2. `bash scripts/devloop/gate.sh`
3. Push and `gh run watch` the `ci` workflow.

## Risks

- Unsetting `DEVLOOP_CONF` in fixtures could hide a deliberate test config; the
  fixture writes its own `.devloop.conf`, so it must not inherit one.
- The isolation is a test harness property, not a product guarantee: the
  top-level gate still honours the environment, by design.

## Notes / decisions

- 2026-10-21: the first real CI run failed 15/68 assertions because the fixtures
  inherited `DEVLOOP_ARTIFACTS` from the gate step and wrote their evidence
  outside their own `.git/devloop`. Local runs never set that variable, which
  is why the unit test suite was green. The harness now unsets the devloop
  environment at startup.
