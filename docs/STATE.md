# STATE — current truth

```yaml
last_verified_sha: f170d9a54cc13982d38c4d5f1e9c797e645ce87f
last_verified_at: 2026-10-22
current_focus: maintenance; quality backlog is optional
```

## Working now

- task-001..013 are integrated and **done**. The loop has a shared artifact store,
  honest gate, committed task contract, review blob, contract floor, integration
  lock, merge gate, PR mode, single-run CI, branch protection, secret scanning,
  non-destructive install, aligned skill/team docs, a tracked bundle, and
  `main-guard` as a second check.
- task-011 made `main-guard` testable (`scripts/devloop/main-guard.sh`) and
  covered six failure paths with a stub `gh`; task-012 hardened the installer
  (PID-suffixed backups, chmod only on kit files, symlink refusal); task-013
  added `prove-red.sh` and corrected the installer docs.
- `bash tests/run.sh` = 134 assertions; doctor = 0 error. Branch protection is
  active (`gate`, admins, PR, no force-push/deletion); secret scanning and push
  protection are enabled.

## Next actions (optional backlog)

1. AC-as-code: declare checks in the task frontmatter and let the gate execute
   them. Needs a YAML-list parser and a design decision; not started.
2. One shared review matcher (`review_covers`) for doctor and integrate; the
   current duplicate works but is a maintenance risk in the safety-critical path.
3. Static analysis in CI (`shellcheck`, `actionlint`, `gitleaks`); evaluate the
   warning volume before wiring it into the required check.
4. Guard residual: detection only; a direct push that edits the workflow/conf
   can blind it. Branch protection remains the barrier.

## Known issues

- `prove-red.sh` is advisory: any non-zero exit counts as red (including a
  setup/import error), test paths are detected by filename, and the base
  worktree lacks untracked dependencies such as `node_modules`.
- `--push` remains untested; review matching is duplicated between doctor and
  integrate; two consecutive linear bookkeeping commits are not recognized.
- The installer refuses symlinked destinations by design; a project that
  deliberately symlinks `.githooks` or `scripts/devloop` must resolve it first.
- The guard is detection, not prevention; the history rewrite risk is unchanged.
- A state-only PR merge once produced no push workflow run (PR #4); protected
  PRs #6..#13 did trigger. Watch this if a state merge looks untested.

## Environment notes

- git 2.47.3, node 24, jq 1.7, flock, timeout.
- GitHub: public repo, Free plan, branch protection active. The workspace
  GitHub environment is sourced outside the repository; `gh` uses a writable
  cache directory. Never commit `.gh`, `.github-env`, `.env` or a key.
- Full check: `bash scripts/devloop/gate.sh` (LINT + 134 tests).
