# STATE — current truth

```yaml
last_verified_sha: 6366aabcbaa80252b5e8ced0ea23da8e1645ddae
last_verified_at: 2026-10-21
current_focus: maintenance; optional quality backlog
```

## Working now

- task-001..009 are integrated and **done**. The loop has a shared artifact store,
  honest gate, committed task contract, review blob, contract floor, integration
  lock, merge gate, PR mode, single-run CI, branch protection, secret scanning,
  non-destructive install, aligned skill/team docs, a tracked bundle, and
  `main-guard` as a second check.
- The repository is public (https://github.com/V4inwald/devloop) and protected:
  required `gate`, PR required with 0 GitHub approvals, admins enforced, no
  force-push or deletion. Secret scanning and push protection are enabled;
  private vulnerability reporting and Dependabot alerts are on.
- task-009 hardened `main-guard` (PR-mode-only, API-failure aware, base-branch
  check), removed the duplicate `task/**` CI trigger, added ADR 0002 (task
  status/bookkeeping), and closed task-001..008. ADR 0002 governs closing
  task-009 in this state PR.
- `bash tests/run.sh` = 119 assertions; doctor = 0 error. PR #7 (task-009) and
  this bookkeeping PR are merged under the protection.

## Next actions (optional quality backlog)

1. AC-as-code: declare checks in the task frontmatter and let the gate execute them.
2. `prove-red.sh`: demonstrate that a new test fails on the pre-change commit.
3. `review_covers`: one matcher shared by doctor and integrate.
4. CI static analysis: `shellcheck`, `actionlint`, `gitleaks` and a bundle-drift
   gate (the bundle is already tested locally).
5. Installer hardening: backup collision within one second, `chmod` of unknown
   files, symlink following under `--force`.
6. Guard hardening: wrap the `gh api` commit lookup, accept single-quoted
   `REQUIRE_PR='true'`, anchor the regex; test the negative path in CI.

## Known issues

- `main-guard` is **detection, not prevention**; a direct push that edits the
  workflow or `.devloop.conf` can blind it. Branch protection is the barrier.
- The guard's commit lookup (`gh api commits/<sha>`) is not wrapped; an API
  failure aborts before the issue (red job, no report).
- `--push` is untested; review matching is duplicated between doctor and
  integrate; two consecutive bookkeeping commits are not recognized.
- A state-only PR merge once produced no push workflow run (observed after PR
  #4); the protected PRs #6..#8 did trigger. Watch this if a state merge looks
  untested.

## Environment notes

- git 2.47.3, node 24, jq 1.7, flock, timeout.
- GitHub: public repo, Free plan, branch protection active. The workspace
  GitHub environment is sourced outside the repository; `gh` uses a writable
  cache directory. Never commit `.gh`, `.github-env`, `.env` or a key.
- Full check: `bash scripts/devloop/gate.sh` (LINT + 119 tests).
