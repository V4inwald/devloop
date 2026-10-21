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
