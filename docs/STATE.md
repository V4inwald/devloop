# STATE — current truth

```yaml
last_verified_sha: fadee5f2cc72d5a2dcb81c5e91711f8586207f4e
last_verified_at: 2026-10-21
current_focus: hardening and executable quality (task-009)
```

## Working now

- task-001..008 are integrated. The loop has a shared artifact store, honest
  gate, committed task contract, review blob, contract floor, integration lock,
  merge gate, PR mode, CI on task branches, non-destructive install, aligned
  skill/team docs, a tracked bundle, and `main-guard` detection.
- task-008 prepared the public release: MIT license, security policy, ignore
  rules, and a full-history audit (`docs/security/pre-public-audit.md`).
- The repository is now **PUBLIC** (https://github.com/V4inwald/devloop). Branch
  protection is applied: required `gate` check, PR required with 0 GitHub
  approvals, admins enforced, no force-push, no deletion. Secret scanning and
  push protection are enabled; private vulnerability reporting and Dependabot
  alerts are on. A direct push to `main` was tested from a scratch clone and
  **rejected** by GitHub.
- `bash tests/run.sh` = 114 assertions; doctor = 0 error. The state update is the
  first bookkeeping PR merged under the protection; `main-guard` verifies it.

## Next actions

1. task-009 hardening: make `main-guard` conditional on `REQUIRE_PR=true` (a
   local-mode project would flag its `chore(merge)` commits), create the issue
   when `gh pr view` fails, check the PR base branch, add a negative guard test,
   test the `protect.sh` 403 mapping, remove the duplicate `gate` run on PRs
   (push `task/**` + pull_request), fix the stale assertion counts in docs.
2. Quality backlog: AC-as-code, `prove-red.sh`, guard tests (empty
   `CONTRACT_PATHS`, `--push`, chained bookkeeping, review order),
   `review_covers` dedup, `shellcheck`/`actionlint`/`gitleaks`/bundle drift in
   CI, task-file `review -> done` ADR.
3. Keep `main-guard` as a second check; branch protection is now the real
   barrier. `--push` remains refused by `REQUIRE_PR=true`.

## Known issues

- `main-guard` is installed unconditionally; a target project using local
  `--push` would get false positives on `chore(merge)` commits.
- If `gh pr view` fails (unknown PR number, API error), the guard exits before
  creating the issue (red job, no report). It only checks `state`/`mergeCommit`,
  not the PR base branch.
- A PR runs `gate` twice (push `task/**` and pull_request), wasting minutes.
- `--push` is untested; review matching is duplicated between doctor and
  integrate; two consecutive bookkeeping commits are not recognized; review
  ordering is reverse-lexicographic.
- Installer: 1-second backup collision, `chmod` of unknown files, symlink
  following under `--force`; new-branch CI policy only checks `HEAD~1`.
- Task-file `review -> done` is still outside the bookkeeping exception;
  task-001..008 stay `review`.
- task-006's AC6 (protection) was blocked when it merged and became true only
  after task-008 made the repository public; the task file records the original
  state, STATE records the resolution.

## Environment notes

- git 2.47.3, node 24, jq 1.7, flock, timeout.
- GitHub: public repo, Free plan, branch protection active. The workspace
  GitHub environment is sourced outside the repository; `gh` uses a writable
  cache directory. Never commit `.gh`, `.github-env`, `.env` or a key.
- Full check: `bash scripts/devloop/gate.sh` (LINT + 114 tests).
