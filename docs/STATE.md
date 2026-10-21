# STATE — current truth

```yaml
last_verified_sha: 5db786b19bca4dbf77b8c99bf0fc1bcc940519ea
last_verified_at: 2026-10-21
current_focus: make GitHub the arbiter (task-006), then executable quality (task-007)
```

## Working now

- task-001 (`cbadcfc`): shared artifact store, honest gate, doctor multi-store.
- task-002 (`c3bc8e4`): task contract, review blob, contract floor, lock,
  detached merge gated before `main`, `--push`, bookkeeping-aware doctor.
- task-003 (`d03b313`): test fixtures isolated from `DEVLOOP_ARTIFACTS`.
- task-004 (`722ff5a`): `pre-push` reads env/git config only; non-destructive
  installer with conflict preflight and `--force` backup; CI on `main` +
  `task/**` with `policy --strict` and actions v7; installable bundle tracked.
- task-005 (`5db786b`): the entry skill, the three procedures, `AGENTS.md`,
  README, design/01, design/04 and the packet header now describe the real
  engine, including a **Team mode** protocol; drift tests pin the bundle mirror.
- `bash tests/run.sh` = 96 assertions; doctor = 0 error; CI run 39643910750 is
  green on the private repo https://github.com/V4inwald/devloop.

## Next actions

1. task-006: GitHub arbitre — choose PR-as-integration (`integrate.sh --pr`),
   branch protection/ruleset on `main` (required `gate`, no force-push, 1
   review), `REQUIRE_CI=true`, CODEOWNERS on contract paths, bundle drift check
   in CI.
2. task-007: executable quality — AC-as-code, `prove-red.sh`, guard tests
   (empty `CONTRACT_PATHS`, `--push`, chained bookkeeping, review order),
   `review_covers` dedup, `shellcheck`/`actionlint`/`gitleaks`/`refresh.sh`
   drift in CI.
3. Docs polish (non-blocking review findings): README says 90 instead of 96,
   `design/03` still mentions `.devloop/artifacts`, drift tests could also cover
   `.githooks`/`.github`/docs templates, installer exit 3 undocumented.

## Known issues

- `main` has no branch protection/ruleset yet. The only push barrier is the
  local hook; `--no-verify` bypasses it, and `REQUIRE_CI` is still false.
- `--push` is implemented but not exercised by the suite; review matching is
  duplicated between doctor and integrate; two consecutive bookkeeping commits
  are not recognized; review ordering is reverse-lexicographic.
- Installer: 1-second backup timestamp collision, `chmod` touches unknown
  hook/script modes, `cp -a` follows a destination symlink under `--force`.
- New-branch CI policy fallback checks only `HEAD~1`.
- Task-file `review -> done` remains outside the bookkeeping exception;
  task-001..005 stay `review` until an ADR settles it.
- `design/02`, `design/03`, `design/06` are historical design notes and still
  carry pre-hardening details; they are not operational docs.

## Environment notes

- git 2.47.3, node 24, jq 1.7, flock, timeout.
- GitHub: `source /workspace/.github-env`; `XDG_CACHE_HOME=/tmp/gh-cache` for
  `gh`. Never commit `.gh` or `.github-env`.
- Full check: `bash scripts/devloop/gate.sh` (LINT + 96 tests).
