# STATE — current truth

```yaml
last_verified_sha: cbadcfca07a23a6257d306b0ebe67754acff54f8
last_verified_at: 2026-10-21
current_focus: hardening the integration step (task-002)
```

## Working now

- task-001 is integrated at `cbadcfc`: evidence lives in the git common
  directory, the gate exits 3 and prints `UNVERIFIED` on a dirty tree, doctor
  reads both the shared and the legacy stores, and CI uploads the relocated
  evidence. `bash tests/run.sh` is at 46 assertions.
- The integration of task-001 used the pre-hardening `integrate.sh`; the merge
  commit itself is therefore not gated yet (`merge_gate` arrives in task-002).

## Next actions

1. task-002: harden `integrate.sh` — committed task contract, review
   immutability (additions only, blob recorded), self-review guard, contract
   paths, integration lock, merge in a detached worktree then gate the merge
   result, `--push`.
2. task-003: non-destructive install, CI on task branches and `policy --strict`,
   pre-push override from the environment only, secret and assertion hardening.
3. task-004: documentation (AGENTS, README, design, packet), worktree helper,
   team-mode protocol, report and metrics.
4. Keep review evidence out of `MAX_DIFF_LINES`; the accounting is tested.

## Known issues

- `integrate.sh` does not write `merge_gate` yet, so doctor reports the
  integrated head as a legacy record (WARN, not ERROR).
- A committed review was edited once (r3 approve -> revise) because it was
  committed before the reviewer finished. See `docs/LESSONS.md`.
- The task-file transition to `done` after integration is not covered by the
  main-branch bookkeeping exception; task-001 stays `review` until an ADR or a
  follow-up task settles the rule.
- The GitHub workflow has never run (no remote, `gh` unauthenticated) and
  `policy.sh` is not `--strict` in CI yet.
- The store move left stale paths in `AGENTS.md`, `README.md`, `design/01`,
  `design/04` and `scripts/devloop/packet.sh`; task-004 owns them.

## Environment notes

- git 2.47.3, node 24, jq 1.7, flock and timeout available.
- Full check: `bash scripts/devloop/gate.sh` (LINT + 46 tests).
