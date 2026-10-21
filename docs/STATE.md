# STATE — current truth

```yaml
last_verified_sha: c3bc8e41d0ad5e30ad6eea914fe5eb8ce01daa9f
last_verified_at: 2026-10-21
current_focus: install, CI and policy hardening (task-003)
```

## Working now

- task-001 integrated at `cbadcfc`: shared artifact store, gate exits 3 and
  says `UNVERIFIED` on a dirty tree, doctor reads shared and legacy stores, CI
  uploads the relocated evidence.
- task-002 integrated at `c3bc8e4`: `integrate.sh` requires a committed task
  contract, binds the approval by blob (additions only after the reviewed SHA),
  rejects self-review without `approved_by` and implementer==reviewer, protects
  a literal contract floor, serializes with `flock`, merges in a detached
  worktree and **gates the merge result** before `main` moves. Doctor fails
  closed on a bookkeeping commit over a non-integration parent.
- `bash tests/run.sh` is at 68 assertions. The task-002 integration was
  explicitly authorized as oversized by the human (677 lines > 400).

## Next actions

1. task-003: non-destructive install, CI on `task/**` plus `policy --strict`,
   environment-only pre-push override, secret and assertion hardening.
2. task-004: documentation (AGENTS, README, design, packet header), worktree
   helper and team-mode protocol, report/metrics.
3. Settle the `review -> done` task-file transition: extend the bookkeeping
   exception by ADR or make it part of a follow-up task.
4. Add the missing guard tests: empty `CONTRACT_PATHS`, `--push`, chained
   bookkeeping commits, review round ordering (`r9` vs `r10`).

## Known issues

- `pre-push` still sources the branch's `.devloop.conf`; `ALLOW_MAIN_PUSH=1`
  or an emptied `PROTECTED_BRANCHES` in that file still bypasses the hook. Fix
  in task-003 (environment-only override).
- `install.sh` still `rm -rf`s existing `.github/workflows/ci.yml`,
  `.githooks/*`, `docs/LESSONS.md` and `scripts/devloop/*` on a first install.
- The GitHub workflow has never run: no remote, `gh` unauthenticated. It still
  triggers only on PR + push to `main`, and `policy.sh` is not `--strict`.
- Stale store paths remain in `AGENTS.md`, `README.md`, `design/01`,
  `design/04` and `scripts/devloop/packet.sh` (task-004).
- `review_covers` in doctor duplicates the integrate matcher; they can drift.
- `--push` is implemented but untested. Two consecutive bookkeeping commits are
  not recognized by doctor.
- task-002 `AC6` still says "63 assertions" in the criterion; a dated note
  records that the suite now reports 68. Acceptance text is not rewritten.

## Environment notes

- git 2.47.3, node 24, jq 1.7, flock and timeout available.
- Full check: `bash scripts/devloop/gate.sh` (LINT + 68 tests).
