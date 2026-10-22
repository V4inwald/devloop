---
id: task-012
status: review
branch: task/012-installer-hardening
created: 2026-10-22
owner: lead
implementer: lead
---

# Installateur : backups distincts, chmod ciblé, symlinks refusés

## Outcome

Three installer holes are closed: two forced installs in the same second get distinct backups,
only the files the kit installs are made executable (a project's own hook/script keeps its
mode), and a destination reached through a symlink is refused instead of written outside the
repository.

## Acceptance criteria

- [x] AC1: the backup path includes the PID and a collision loop; a second forced install keeps a separate backup.
- [x] AC2: the executable bit is applied only to the paths coming from the kit assets; a custom `.githooks/commit-msg` and `scripts/devloop/deploy.sh` keep mode 644.
- [x] AC3: a symlink in the destination path is detected in the preflight (targets and `AGENTS.devloop.md`), the installer exits 4, and nothing is written through it.
- [x] AC4: tests cover the three cases; gate/doctor pass; the bundle is unchanged (the installer is the shipped artefact).

## Scope

Touched: `dist/devloop-skill/install.sh`, `tests/run.sh`, `docs/tasks/task-012.md`.

## Verification plan

1. `bash tests/run.sh` (>= 130 assertions).
2. `bash scripts/devloop/gate.sh`.
3. PR merge under protection.

## Risks

- Refusing symlinks can surprise a project that deliberately symlinks `.githooks` or
  `scripts/devloop`; the error names the path and asks for manual removal. Erring on the safe
  side is intentional: a write through a symlink can escape the repository.
- The PID suffix is not a security boundary; the loop handles the residual collision.
