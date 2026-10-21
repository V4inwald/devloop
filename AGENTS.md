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
(`docs/STATE.md`, `docs/LESSONS.md`) directly to `main` with a `chore(state):` or `docs(state):`
message. Nothing else is exempt, and the update must not touch code or tests.

## 3. Evidence model

Evidence is bound to a commit SHA, not to a conversation:

- `scripts/devloop/gate.sh` writes `.devloop/artifacts/gate/<sha>/result.json` and refuses to
  count a dirty tree as passing.
- A review file `docs/reviews/<task>-r<N>.md` names the exact `sha:` it approved.
- `scripts/devloop/integrate.sh` merges only when both exist for HEAD. Code committed after
  review invalidates the review (only additions under `docs/reviews/` are tolerated).

An agent saying "tests pass" is not evidence. The artifact is.

## 4. The loop

| Step | Command | Produces |
|---|---|---|
| 1. Task | write `docs/tasks/<id>.md` | acceptance criteria + checks |
| 2. Branch | `git switch -c task/<id>-<slug>` | isolated work |
| 3. Implement | small commits, conventional messages | code + tests |
| 4. Gate | `bash scripts/devloop/gate.sh` | `<sha>/result.json` |
| 5. Review | `bash scripts/devloop/packet.sh`, then a separate reviewer writes `docs/reviews/<task>-r1.md` | verdict |
| 6. Integrate | `bash scripts/devloop/integrate.sh --task <id>` | merge commit + audit record |
| 7. Record | update `docs/STATE.md`; add a lesson or ADR if a decision was made | durable state |

Full procedure: skill `dev-cycle`. Review rubric: skill `code-review`. Task format: skill
`task-authoring`.

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
- Merge commits are created by `integrate.sh`, never hand-crafted.

## 7. Review

- The reviewer is a separate context from the implementer. Never approve your own diff.
- Solo fallback: self-review is allowed only with `reviewer: self` in the verdict and explicit
  human approval before integration.
- `approve` requires zero blockers. "Looks fine" without per-rubric evidence is not a review.
- Maximum two review rounds; after that escalate to the human.

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
- [ ] Review file approved that SHA with zero blockers.
- [ ] Merge performed by `integrate.sh`.
- [ ] `docs/STATE.md` updated; lesson or ADR recorded if applicable.
