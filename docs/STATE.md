# STATE — current truth

```yaml
last_verified_sha: 722ff5a2ca7ccf5f6ab4a339ffbcae9119b99d62
last_verified_at: 2026-10-21
current_focus: align the skill and its team protocol (task-005)
```

## Working now

- task-001 (`cbadcfc`): shared artifact store, honest gate, doctor multi-store,
  relocated CI evidence.
- task-002 (`c3bc8e4`): task contract, review blob/immutability, self-review
  guard, literal contract floor, lock, detached merge gated before `main`,
  `--push`, bookkeeping-aware doctor.
- task-003 (`d03b313`): test fixtures isolated from the caller's
  `DEVLOOP_ARTIFACTS`; first real CI failure fixed.
- task-004 (`722ff5a`): `pre-push` no longer reads `.devloop.conf`; installer is
  non-destructive with conflict preflight and `--force` backup; CI runs on
  `main` + `task/**` with `policy --strict` and actions v7; the installable
  skill bundle is tracked in git. CI run 39642761499 is green.
- `bash tests/run.sh` = 90 assertions; doctor = 0 error. The private repo is
  https://github.com/V4inwald/devloop (visibility `PRIVATE`).

## Next actions

1. task-005: align the skill and docs with the engine — `dist/devloop-skill/SKILL.md`
   ("Team mode", install/CI/merge-gate procedure), `dev-cycle`, `code-review`,
   `task-authoring`, `AGENTS.md`, `README`, `design/01`, `design/04`,
   `packet.sh`; refresh the bundle. Optional helpers: `worktree.sh`,
   `report.sh`.
2. task-006: GitHub arbitre — choose PR-as-integration, branch protection on
   `main` (required `gate`, no force-push, 1 review), `REQUIRE_CI=true`,
   CODEOWNERS on contract paths, CI drift check for the bundle.
3. task-007: executable quality — AC-as-code, `prove-red.sh`, guard tests
   (empty `CONTRACT_PATHS`, `--push`, chained bookkeeping, review order),
   `review_covers` dedup, `shellcheck`/`actionlint`/`gitleaks`.
4. Private by default: encode `publish.sh`/docs (memory already records it).

## Known issues

- `main` has no branch protection/ruleset yet: the only push barrier is the
  local hook, bypassable with `--no-verify`. `REQUIRE_CI` is still false.
- The tracked bundle duplicates the source (`dist/devloop-skill/assets`); a CI
  drift check (`diff -r`) is missing, and `refresh.sh` must be run on every
  engine/skill change.
- `.devloop.conf.example` still advertises `PROTECTED_BRANCHES`, which the hook
  now ignores (env/git config only); fix with the docs.
- Installer: 1-second backup timestamp collision, `chmod` touches unknown
  hook/script modes, `cp -a` follows a destination symlink under `--force`.
- New-branch CI policy fallback only checks `HEAD~1`.
- `review_covers` (doctor) duplicates the integrate matcher; `--push` is
  untested; two consecutive bookkeeping commits are not recognized; review
  ordering is reverse-lexicographic.
- Task-file `review -> done` is not covered by the bookkeeping exception;
  task-001..004 stay `review` until an ADR settles it.

## Environment notes

- git 2.47.3, node 24, jq 1.7, flock, timeout.
- GitHub: `source /workspace/.github-env`; `XDG_CACHE_HOME=/tmp/gh-cache` for
  `gh`. Never commit `.gh` or `.github-env`.
- Full check: `bash scripts/devloop/gate.sh` (LINT + 90 tests).
