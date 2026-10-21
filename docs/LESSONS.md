# LESSONS — one line per lesson

Append only. Newest last. Dated, linked to a task, written so the next agent can act on it
without reading the whole history. No platitudes: a lesson names a decision rule.

Format: `- YYYY-MM-DD (task-NNN): <what happened> → <what to do differently>.`

- 2026-10-21 (bootstrap): agents over-report success → never accept "tests pass" without a gate
  artifact for the current SHA.
- 2026-10-21 (task-001): a review file committed before the reviewer reported its final verdict
  had to be rewritten (r3 approve → revise) → never commit `docs/reviews/*.md` until the reviewer
  says it is done; the file is evidence, not a draft.
- 2026-10-21 (task-001): verdict files themselves consumed the diff budget (413 > 400) → exclude
  `docs/reviews/` from `MAX_DIFF_LINES`; evidence is the output of the review, not the change.
- 2026-10-21 (task-001): two independent reviewers on one SHA disagreed (r2 revise, r3 approve)
  → the stricter blocker wins; never average or cherry-pick verdicts.
- 2026-10-21 (task-001): `runner` is step-scoped in GitHub Actions → never use `${{ runner.* }}`
  in `jobs.<id>.env`; the workflow fails validation before any job starts.
- 2026-10-21 (task-002): gating the task branch is not gating the merge → always merge in a
  detached worktree, run the gate on the merge result, then move `main`; semantics can conflict
  even when the text does not.
- 2026-10-21 (task-002): a "non-overridable" floor must be a literal assignment after the config
  is sourced → any variable set before sourcing `.devloop.conf` can be emptied by the branch.
- 2026-10-21 (task-002): doctor must fail closed on a bookkeeping commit whose parent is not an
  integration merge → a gated+reviewed fast-forward tip otherwise passes without integration.
- 2026-10-21 (task-002): the human explicitly authorized an oversized integration (677 > 400) →
  record the exception in STATE/LESSONS, never pass `--allow-oversized` silently.
- 2026-10-21 (process): two review rounds ended on a one-line blocker; a third delta review of
  the fix is cheaper than merging a known hole → escalate, get the human authorization, then
  review the delta (not the whole task) instead of abandoning the change.
- 2026-10-21 (task-003): local green is not CI green → test fixtures must unset the caller's
  `DEVLOOP_ARTIFACTS`/`DEVLOOP_CONF`, and the first GitHub Actions run is the only proof the
  workflow actually works; run it before claiming CI evidence.
- 2026-10-21 (GitHub): authentication lives in `/workspace/.github-env` (account `V4inwald`),
  and a new repository is **private by default**; the initial push to `main` needs the explicit
  `ALLOW_MAIN_PUSH=1` release override, which is the hook working as designed.
- 2026-10-21 (task-004): the installable bundle was excluded from git by a local
  `.git/info/exclude` → check `git ls-files` for the product, not just the working tree; a repo
  that ships a skill must track the skill, and CI must exercise the installer.
- 2026-10-21 (task-004): a branch must not be able to read its own push-protection config →
  `pre-push` takes the decision from the environment/git config only, and `main master` are
  always prepended.
- 2026-10-21 (task-004): an installer must preflight every conflict, back up on `--force`, and
  never `rm -rf` a directory it did not create → the first install into an existing repo must
  preserve unknown hooks, workflows and lessons.
- 2026-10-21 (task-005): a skill that names the old store or the old commands is worse than no
  skill → every engine change must update the entry skill and the three procedures, and a drift
  test must pin the bundle mirror to the source.
- 2026-10-21 (task-005): in team mode the review file is the handoff artefact (`task:`, `sha:`,
  blob), never a chat message or a shared draft → one writer per worktree, one integrator at a
  time, one review per task.
- 2026-10-21 (task-006): a server-side control is only as real as the plan →
  GitHub branch protection and rulesets are unavailable on private repositories
  on Free; verify the plan before designing on it, and state the residual risk
  instead of claiming enforcement.
- 2026-10-21 (task-006): dogfooding an integration path is not proof of the
  protection it is supposed to run under → test the actual rejection separately;
  the PR flow can be green while direct pushes remain possible.
- 2026-10-21 (task-006): when `main` cannot be pushed directly, bookkeeping
  (`STATE.md`/`LESSONS.md`) travels through a short `state/<sha>` PR; the
  substance of the exception is unchanged, only its transport.
- 2026-10-21 (task-007): detection is not prevention → say it in the docs and
  test the positive and negative paths with a stub, including a forged
  "Merge pull request #N" subject.
- 2026-10-21 (task-007): a private repository on GitHub Free cannot have branch
  protection or rulesets (403) → decide public/Pro or accept detection, and test
  the real rejection instead of assuming the plan allows it.
- 2026-10-21 (process): `git add -A` in a workspace that also contains harness
  artifacts (`.plugin-work/`) swept 2 700 unrelated lines into a commit → stage
  explicit paths and inspect `git status` before committing.
