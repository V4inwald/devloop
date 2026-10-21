# STATE — current truth

```yaml
last_verified_sha: 8d5e3a9c7ec8a3d9f5a54fd5195ab8b8c3cda950
last_verified_at: 2026-10-21
current_focus: decide private/public, then task-008 hardening
```

## Working now

- task-001..007 are integrated. The loop has a shared artifact store, honest
  gate, committed task contract, review blob, contract floor, integration lock,
  merge gate, PR mode, CI on task branches, non-destructive install, aligned
  skill/team docs, and a tracked installable bundle.
- task-006 was merged through PR #1, task-007 through PR #3. The `--pr` path
  waits for the `gate` checks, merges on GitHub, then gates the GitHub merge
  commit locally before moving local `main`.
- task-007 added `main-guard` (detection of non-PR pushes on `main`). Its run on
  the task-007 merge is green: 39648871136. It is **detection, not prevention**.
- GitHub Free refuses branch protection/rulesets on this private repository
  (403). `protect.sh` is ready but cannot be applied; the repo stays private for
  now, so direct pushes are possible and only detected.
- `bash tests/run.sh` = 110 assertions; doctor = 0 error.

## Next actions

1. Decide the repository visibility. Recommendation: make this **skill** public
   after a pre-public audit (full-history secret scan, scrub operational paths,
   add LICENSE/SECURITY.md, enable secret scanning and push protection), then
   apply `protect.sh` and keep `main-guard` as a second check. Keep project
   repositories private; a public skill does not expose them.
2. task-008 hardening: guard only for PR-mode projects (local-mode `--push`
   currently produces `chore(merge)` commits that the guard would flag), guard
   issue creation on `gh pr view` failure, check the PR base branch, test the
   negative guard path, `protect.sh` 403 mapping test, duplicate `gate` runs on
   PR (push `task/**` + pull_request), README/design counts.
3. Quality backlog: AC-as-code, `prove-red.sh`, guard tests (empty
   `CONTRACT_PATHS`, `--push`, chained bookkeeping, review order),
   `review_covers` dedup, `shellcheck`/`actionlint`/`gitleaks`/bundle drift in
   CI, task-file `review -> done` ADR.

## Known issues

- **No server-side protection on this private repo (GitHub Free).** Direct
  pushes to `main` remain possible; `main-guard` reports them after the fact.
- `main-guard` is installed unconditionally; a target project using local
  `--push` would get false positives on `chore(merge)` commits. It should be
  installed/run only when `REQUIRE_PR=true`.
- If `gh pr view` fails (unknown PR number, API error), the guard exits before
  creating the issue (red job, no report). It only checks `state`/`mergeCommit`,
  not the PR base branch.
- `--push` is untested; review matching is duplicated between doctor and
  integrate; two consecutive bookkeeping commits are not recognized; review
  ordering is reverse-lexicographic.
- Installer: 1-second backup collision, `chmod` of unknown files, symlink
  following under `--force`; new-branch CI policy only checks `HEAD~1`.
- Task-file `review -> done` is still outside the bookkeeping exception;
  task-001..007 stay `review`.
- `.plugin-work/` is a harness artifact; it was once swept into a commit with
  `git add -A` and removed by amending. It is locally excluded now.

## Environment notes

- git 2.47.3, node 24, jq 1.7, flock, timeout.
- GitHub: `source /workspace/.github-env`; `XDG_CACHE_HOME=/tmp/gh-cache` for
  `gh`. Account `V4inwald`, private repo, Free plan (no private branch
  protection). `main-guard` and `ci` are active.
- Full check: `bash scripts/devloop/gate.sh` (LINT + 110 tests).
