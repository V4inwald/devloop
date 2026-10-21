# AGENTS.md — <PROJECT NAME> development contract

This file is the repository's hot memory. DSH loads it automatically for every request.
Read it fully before changing anything. If a request conflicts with a rule here, stop and ask
the human; do not quietly pick one side.

## 1. What this repository is

<One short paragraph: purpose, stack, how it runs. Keep it stable; details belong in docs/.>

## 2. Non-negotiables

1. Never commit directly to `main`. Work on `task/<id>-<slug>`.
2. Every change has a task file in `docs/tasks/` with acceptance criteria and a verification plan.
3. Evidence over claims. Work is done only when a gate result and a review file both cover HEAD.
4. Never weaken, skip, or delete a test to make a gate pass. Any test change is justified in the task file.
5. Never force-push, never `git reset --hard` a shared branch, never rewrite public history.
6. No secrets, tokens, credentials, or personal data in code, logs, fixtures, or commits.
7. Do not edit evidence (gate results, review verdicts) to match reality; re-run the check instead.
8. One task = one reviewable change. Stay under `MAX_DIFF_LINES`; split otherwise.

Exception to rules 1–3: after an integration, the integrator may commit bookkeeping
(`docs/STATE.md`, `docs/LESSONS.md`, and the integrated task file's `status` plus its acceptance
checkboxes) directly to `main` with a `chore(state):`/`docs(state):` message when `main` is not
protected, or through a `state/<sha>` pull request when it is. Acceptance text is never
rewritten. Nothing else is exempt, and the update must not touch code or tests. See ADR 0002.

## 3. Evidence model

Evidence is bound to a commit SHA, not to a conversation:

- `scripts/devloop/gate.sh` writes `$(git rev-parse --git-common-dir)/devloop/gate/<sha>/result.json`.
  The store is shared by every worktree and never sits inside the worktree. A dirty tree exits
  3 and prints `UNVERIFIED`; it is never a passing result.
- A review file `docs/reviews/<task>-r<N>.md` names the exact `sha:` it approved, its `task:`,
  and `contract: approved` when the branch touches contract paths. The file must be **added
  after** the reviewed commit; its blob is pinned in the integration record and the merge
  trailers.
- `scripts/devloop/integrate.sh` merges only when the committed task contract, the gate and the
  review all cover HEAD. Code committed after review invalidates it (only additions under
  `docs/reviews/` are tolerated). The merge result is gated in a detached worktree before
  `main` moves.

An agent saying "tests pass" is not evidence. The artifact is.

## 4. The loop

| Step | Command | Produces |
|---|---|---|
| 1. Task | write `docs/tasks/<id>.md` | acceptance criteria + checks |
| 2. Branch | `git switch -c task/<id>-<slug>` | isolated work |
| 3. Implement | small commits, conventional messages | code + tests |
| 4. Gate | `bash scripts/devloop/gate.sh` | `<sha>/result.json` (exit 3 = dirty, not integrable) |
| 5. Review | `bash scripts/devloop/packet.sh`, then a separate reviewer writes `docs/reviews/<task>-r1.md` | verdict + blob |
| 6. Integrate | `bash scripts/devloop/integrate.sh --task <id> [--pr]` | gated merge commit + audit record |
| 7. Record | update `docs/STATE.md`; add a lesson or ADR if a decision was made | durable state |

Full procedure: skill `dev-cycle`. Review rubric: skill `code-review`. Task format: skill
`task-authoring`.

When `REQUIRE_PR=true`, `integrate.sh --pr` is the only integration path: the branch is
pushed, the required `gate` check must be green on the pull request, and GitHub merges it.
`scripts/devloop/protect.sh` applies the branch protection (admins included) **where the
plan allows it**; GitHub Free cannot protect a private branch. On that plan the shipped
`main-guard` workflow detects a non-PR push (issue + red job) but does not prevent it;
prevention requires a public repository or GitHub Pro/Team. The bookkeeping exception still
applies in substance, but it travels through a short `state/<sha>` pull request when
protection (or `REQUIRE_PR=true`) is in force.

## 5. Memory map

| Path | Layer | Update rule |
|---|---|---|
| `AGENTS.md` | hot, always loaded | stable rules only; changes reviewed like code |
| `.agents/skills/*/SKILL.md` | procedures, loaded on demand | version with the process |
| `docs/STATE.md` | current state + next actions | after every integration, stamped with the SHA |
| `docs/tasks/<id>.md` | task contract | append decisions; never rewrite acceptance after the fact |
| `docs/adr/NNNN-*.md` | architectural decisions | immutable once accepted; supersede with a new ADR |
| `docs/reviews/*.md` | review verdicts | immutable after merge |
| `docs/LESSONS.md` | one-line lessons | append, dated, linked to a task |
| git history / PRs | raw truth | never rewritten |

Do not copy details into `AGENTS.md`. It must stay small enough to be read at every request.

## 6. Git conventions

- Branches: `task/<id>-<slug>`.
- Commits: Conventional Commits, imperative, lowercase summary, ≤72 characters.
- One logical change per commit; tests live in the commit that needs them.
- Commit body: why, not what. Reference `task-<id>` in the body when useful.
- Merge commits are created by `integrate.sh` or by the GitHub PR merge, never hand-crafted.

## 7. Review

- The reviewer is a separate context from the implementer. Never approve your own diff.
- The review file must be **added after** the reviewed commit and is never committed as a draft.
  `integrate.sh` pins its blob; after the reviewed SHA only `A docs/reviews/` is tolerated.
- The review declares `task:`, `sha:`, `reviewer:`, and `contract:` when the branch changes a
  contract path. `reviewer: self` requires `approved_by:` and explicit human approval.
- `approve` requires zero blockers. "Looks fine" without per-rubric evidence is not a review.
- Maximum two review rounds; after that escalate to the human.
- Team mode: one writer per worktree, one integrator at a time, one review per task. The review
  file is the handoff artefact — never a chat message, never a shared draft.

## 8. Session start

1. Read `docs/STATE.md`.
2. Run `bash scripts/devloop/doctor.sh`; if it reports errors, fix them before new work.
3. Read the task file you are about to work on.
4. If state is stale (`last_verified_sha` != HEAD), re-verify before trusting it.

## 9. Escalate to the human

- Acceptance criteria are ambiguous or contradictory.
- The fix requires touching a protected area (auth, payments, migrations, CI, secrets).
- Two review rounds failed.
- Evidence cannot be produced (missing service, credentials, flaky test).
- A rule above must be broken.

State what you need, the options, and your recommendation. Do not guess silently.

## 10. Definition of done

- [ ] Task file status is `done`, acceptance criteria checked.
- [ ] Gate passed on a clean tree for the reviewed SHA.
- [ ] Review file approved that SHA with zero blockers; its blob is recorded.
- [ ] Merge performed by `integrate.sh`, and the merge result passed the gate.
- [ ] `docs/STATE.md` updated; lesson or ADR recorded if applicable.
