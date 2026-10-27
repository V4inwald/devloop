---
id: task-014
status: review
branch: task/014-owner-review
created: 2026-10-23
owner: lead
implementer: comptetest101
---

# Revue owner obligatoire : `--pr` s'arrête et reprend après approbation

## Outcome

With `REQUIRED_APPROVALS=1`, `integrate.sh --pr` no longer fails with a generic
`gh pr merge` error: it detects `reviewDecision`, stops with an actionable
message, and merges only after the owner/reviewer approved. The identity model
and isolation rules are documented.

## Acceptance criteria

- [x] AC1: `--pr` reads `reviewDecision`; `REVIEW_REQUIRED` and `CHANGES_REQUESTED` stop with a precise message; `APPROVED` (or no protection) merges.
- [x] AC2: `docs/security/identity-model.md` documents the roles, token scopes, isolation, and residual risks; README/SKILL/AGENTS point to it.
- [x] AC3: tests and gate pass; the bundle is refreshed.
- [ ] AC4 (post-merge): the first PR under 1 approval is opened by `comptetest101`, approved by `V4inwald`, and merged by the agent.

## Scope

Touched: `scripts/devloop/integrate.sh`, `docs/security/identity-model.md`,
`README.md`, `dist/devloop-skill/SKILL.md`, `AGENTS.md`, `tests/run.sh`,
`docs/tasks/task-014.md`, refreshed bundle.

## Verification plan

1. `bash tests/run.sh`.
2. `bash scripts/devloop/gate.sh`.
3. Push/open the PR with `comptetest101`; confirm `--pr` stops at `REVIEW_REQUIRED`.
4. Owner approves; re-run `--pr`; merge.

## Risks

- The owner becomes the bottleneck (~30 s per PR); that is intentional.
- An AI reviewer on the owner account is delegated authorization, not human
  judgment; high-risk paths still need the human.
