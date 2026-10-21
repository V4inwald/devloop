# STATE — current truth

```yaml
last_verified_sha: d03b31342c83d1ac1d8f49ab850f5c27828bddac
last_verified_at: 2026-10-21
current_focus: closing the hard holes (task-004), then docs/team (task-005)
```

## Working now

- task-001 (`cbadcfc`): shared artifact store, honest gate, doctor multi-store,
  relocated CI evidence.
- task-002 (`c3bc8e4`): task contract, review blob/immutability, self-review
  guard, literal contract floor, integration lock, detached merge gated before
  `main` moves, `--push`, bookkeeping-aware doctor.
- task-003 (`d03b313`): test fixtures no longer inherit `DEVLOOP_ARTIFACTS`
  from the gate; the first real GitHub Actions run (39637592566) failed 15/68
  on that exact leak, and the merge run 39638308945 is **green**.
- `bash tests/run.sh` = 68 assertions; doctor = 0 error/warning.
- The private GitHub repository is live: https://github.com/V4inwald/devloop
  (visibility `PRIVATE`, account `V4inwald`). GitHub auth lives in
  `/workspace/.github-env`; source it before `gh`/`git` in a new shell.

## Next actions

1. task-004: close the hard holes — pre-push override from the environment only
   (the current hook still sources `.devloop.conf`), non-destructive
   `install.sh`, CI on `task/**` with `policy --strict`.
2. task-005: align the skill and docs — `SKILL.md` "Team mode", `dev-cycle`,
   `code-review`, `AGENTS.md`, `README`, `design/01`, `design/04`, `packet.sh`;
   `worktree.sh`; `report.sh`.
3. task-006: GitHub arbitre — choose PR-as-integration, branch protection on
   `main` (required `gate`, no force-push, 1 review), `REQUIRE_CI=true`,
   CODEOWNERS on contract paths. Private by default (already enforced for this
   repo; encode it in `publish.sh`).
4. task-007: executable quality — AC-as-code, `prove-red.sh`, missing guard
   tests (empty `CONTRACT_PATHS`, `--push`, chained bookkeeping, review order),
   `review_covers` dedup, `shellcheck`/`actionlint`/`gitleaks`.

## Known issues

- `pre-push` still sources the branch's `.devloop.conf`: an uncommitted
  `ALLOW_MAIN_PUSH=1` bypasses it. The initial push used the documented
  `ALLOW_MAIN_PUSH=1` release override.
- `install.sh` still overwrites existing `.github/workflows/ci.yml`,
  `.githooks/*`, `docs/LESSONS.md` and `scripts/devloop/*` on a first install.
- The CI workflow still triggers only on PR + push `main`; `policy.sh` is not
  `--strict` there. No branch protection / required checks yet.
- Stale store paths remain in `AGENTS.md`, `README.md`, `design/01`,
  `design/04`, `scripts/devloop/packet.sh`; `SKILL.md` has no team-mode
  protocol yet.
- `review_covers` (doctor) still duplicates the integrate matcher; `--push` is
  untested; two consecutive bookkeeping commits are not recognized; review
  ordering is reverse-lexicographic (`r9` before `r10`).
- Task-file `review -> done` is still not covered by the bookkeeping exception;
  task-001/002/003 stay `review` until an ADR settles it.

## Environment notes

- git 2.47.3, node 24, jq 1.7, flock, timeout, actionlint unavailable locally.
- GitHub: `source /workspace/.github-env`; `gh` cache needs
  `XDG_CACHE_HOME=/tmp/gh-cache` under the sandbox. Never commit `.gh` or
  `.github-env`.
- Full check: `bash scripts/devloop/gate.sh` (LINT + 68 tests).
