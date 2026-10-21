---
id: task-008
status: done
branch: task/008-public
created: 2026-10-21
owner: lead
implementer: lead
---

# Audit pré-public et passage en public

## Outcome

The repository is audited for credentials, licensed and given a security policy,
then made public so GitHub can enforce branch protection and secret scanning on
a free plan; `main` becomes merge-only through `--pr`.

## Acceptance criteria

- [x] AC1: full-history audit (gitleaks over all refs + working tree, manual pattern and file-name checks, large-blob check) is documented and clean.
- [x] AC2: `LICENSE` (MIT), `SECURITY.md`, `.gitignore` (secrets, `.devloop/`, `.plugin-work/`) and `docs/security/pre-public-audit.md` are added; current docs no longer expose the workspace auth path.
- [x] AC3: tests assert the public-readiness files and ignore rules; `bash tests/run.sh` passes and the gate is clean.
- [x] AC4 (post-merge): the repository is public, secret scanning and push protection are enabled, `protect.sh` is applied, a direct push to `main` is rejected, and a bookkeeping PR is merged under the protection.

## Scope

Touched: `LICENSE`, `SECURITY.md`, `.gitignore`,
`docs/security/pre-public-audit.md`, `docs/STATE.md`, `docs/LESSONS.md`,
`README.md`, `tests/run.sh`, `docs/tasks/task-008.md`.

Out of scope: rewriting history (nothing sensitive was found), the quality
backlog (task-009), changing the public/private policy of other projects.

## Verification plan

1. `bash tests/run.sh`.
2. `bash scripts/devloop/gate.sh`.
3. Merge via `--pr`, then `gh repo edit --visibility public`.
4. Check `protect.sh`, secret scanning, push protection, direct-push rejection.
5. Merge a `state/<sha>` PR under the protection.

## Risks

- Making the repository public is effectively irreversible and the whole history
  becomes public. The audit is point-in-time; a future secret would be exposed
  immediately, hence push protection.
- Branch protection on public repos is free, but a single-account repo cannot
  require GitHub approvals (self-approval is forbidden); the file review remains
  the process gate and `REQUIRED_APPROVALS=0`.
- The home-lab and other private projects are not in this repository; the skill
  is a public tool, their data stays private.

## Notes / decisions

- 2026-10-21: the repository is public, branch protection is active (`gate`, admins, PR, no
  force-push/deletion), secret scanning and push protection are enabled, and a direct push was
  rejected from a scratch clone. AC4 is met; the task file is closed under ADR 0002.
