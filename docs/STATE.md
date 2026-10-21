# STATE — current truth

```yaml
last_verified_sha: 6dbf58744fe74494aeb7d346c19f0625d959d4f5
last_verified_at: 2026-10-21
current_focus: protection fallback and executable quality (task-007)
```

## Working now

- task-001..005 are integrated (shared store, honest gate, integration contract,
  review blob, merge gate, CI on task branches, install safety, skill/team docs).
- task-006 (`6dbf587`) added `integrate.sh --pr` and was merged **through its own
  PR #1** (https://github.com/V4inwald/devloop/pull/1). The PR gate ran twice
  (push + pull_request), both green; the GitHub merge commit was gated locally
  before the local `main` moved. `REQUIRE_PR=true` refuses local mode.
- `scripts/devloop/protect.sh` is written and dry-run-tested, but **cannot be
  applied to this repository**: GitHub Free refuses branch protection and
  rulesets on private repositories (HTTP 403, "Upgrade to GitHub Pro or make
  this repository public"). The protection payload requires the `gate` check,
  admins included, no force-push/deletion, a PR with zero approvals.
- `bash tests/run.sh` = 104 assertions; CI run 39646585688 is green on `main`.

## Next actions

1. Decide the protection fallback: (a) keep the private repo and add a
   **detection** workflow on `main` (revert/issue when a push is not a PR
   merge), (b) make the repo public (branch protection becomes free, but
   contradicts the private-by-default preference), or (c) GitHub Pro/Team.
   Recommendation: (a), and document the residual direct-push risk.
2. task-007: executable quality — AC-as-code, `prove-red.sh`, guard tests
   (empty `CONTRACT_PATHS`, `--push`, chained bookkeeping, review order),
   `review_covers` dedup, `shellcheck`/`actionlint`/`gitleaks`/bundle drift in
   CI, and the private-Free limitation in README/SKILL/AGENTS.
3. Fix the non-blocking review findings: README says 102 assertions (now 104);
   `design/03` old path; poll error attribution; duplicate `gate` runs on PR
   (push `task/**` + pull_request); task-file `review -> done` rule.
4. Bookkeeping now travels through a `state/<sha>` PR (this one) because
   `REQUIRE_PR=true`; direct pushes are still possible on the plan, but the
   process forbids them.

## Known issues

- **No server-side protection on this private repo (GitHub Free).** Direct
  pushes to `main` are possible with `ALLOW_MAIN_PUSH=1`; the local hook, the
  PR workflow and `REQUIRE_PR=true` are process controls, not enforcement. The
  README/SKILL claims about protection must be qualified.
- `protect.sh` exits 2 with the raw GitHub 403 on this plan; it should emit the
  upgrade/public options and a fallback hint.
- A PR runs `gate` twice (push `task/**` and `pull_request`); wasted minutes.
- `--push` is untested; review matching is duplicated between doctor and
  integrate; two consecutive bookkeeping commits are not recognized; review
  ordering is reverse-lexicographic.
- Installer: 1-second backup collision, `chmod` of unknown files, symlink
  following under `--force`; new-branch CI policy only checks `HEAD~1`.
- Task-file `review -> done` is still outside the bookkeeping exception;
  task-001..006 stay `review`.

## Environment notes

- git 2.47.3, node 24, jq 1.7, flock, timeout.
- GitHub: `source /workspace/.github-env`; `XDG_CACHE_HOME=/tmp/gh-cache` for
  `gh`. Account `V4inwald`, private repo, Free plan (no private branch
  protection).
- Full check: `bash scripts/devloop/gate.sh` (LINT + 104 tests).
