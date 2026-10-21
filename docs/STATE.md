# STATE — current truth

```yaml
last_verified_sha: ed30cdb679ec778a83df90278c8a89fa401a2533
last_verified_at: 2026-10-21
current_focus: adoption on a first real repository
```

## Working now

- No active task. The kit is bootstrapped on `main` at `ed30cdb`, gated (LINT + TEST pass),
  merged from `task/000-bootstrap`.

## Next actions

1. Copy the kit into a real repository, adapt `.devloop.conf`, run `install-hooks.sh`.
2. Run one short real task with a subagent reviewer, and keep the first verdict file.
3. Turn on branch protection and required checks; authenticate `gh`; set `REQUIRE_CI=true`.
4. Record the baseline metrics: gate first-pass rate, review blocker rate, time per task.

## Known issues

- The bootstrap merge is unreviewed by design (pre-adoption). `doctor.sh` reports it as an error;
  this is expected until the first task is integrated through `integrate.sh`.
- `doctor.sh` warns when `STATE.md` is updated by a `chore(state):` commit, because it compares
  the recorded SHA with HEAD. Anchoring evidence past bookkeeping commits is a planned fix.
- The GitHub Actions workflow has never been executed: no remote, `gh` is not authenticated.
- `policy.sh` secret detection is a regex heuristic, not a dedicated scanner.
- The review path is exercised by the test harness, not by an independent LLM review of this
  bootstrap.

## Environment notes

- git 2.47.3, node v24.22.0, jq present, bash 5.
- Full check: `bash scripts/devloop/gate.sh` (runs `tests/run.sh`, 29 assertions).
