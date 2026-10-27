---
id: task-016
status: review
branch: task/016-harness-check
created: 2026-10-27
owner: lead
implementer: lead
---

# `harness-check.sh` : les règles fatales deviennent incontournables

## Outcome

Un script `scripts/devloop/harness-check.sh` vérifie les quatre règles structurelles du harness et
est câblé dans `CHECK_LINT` ; la suite prouve qu'il passe sur le kit et échoue sur cinq fixtures
fautives.

## Acceptance criteria

- [ ] AC1: `bash scripts/devloop/harness-check.sh` sort 0 sur ce dépôt et affiche `OK`.
- [ ] AC2: il sort 1 pour chacun des cinq cas : skill orpheline, `{{` dans `AGENTS.md`, script
      nommé absent, `AGENTS.md` de 160 lignes, `AGENTS.md` absent.
- [ ] AC3: `bash tests/run.sh` passe, avec 7 assertions de plus qu'avant (134 → 141).
- [ ] AC4: `.devloop.conf` exécute le script via `CHECK_LINT` ; `bash scripts/devloop/gate.sh`
      sort 0 sur un arbre propre.
- [ ] AC5: le miroir `dist/devloop-skill/assets/scripts/devloop/harness-check.sh` est identique.
- [ ] AC6: `README.md` annonce le compte d'assertions réel et l'adoption opt-in.
- [ ] AC7: une revue indépendante approuve ce SHA avec `contract: approved` (`.devloop.conf`).

## Scope

Touched: `scripts/devloop/harness-check.sh`, `.devloop.conf`, `tests/run.sh`, `README.md`,
`dist/devloop-skill/assets/scripts/devloop/harness-check.sh`, `docs/tasks/task-016.md`.

Out of scope: `AGENTS.md`, `.agents/skills/**`, version du kit, `dist/devloop-skill/SKILL.md`.

## Verification plan

1. `bash scripts/devloop/harness-check.sh` → exit 0.
2. `bash tests/run.sh` → `passed: 141, failed: 0`.
3. `bash scripts/devloop/gate.sh` sur arbre propre.
4. Revue indépendante.

## Risks

- Un faux positif casserait le gate de tout contributeur : le script ne lit que `AGENTS.md` et
  `.agents/skills/`, et les projets installés ne l'exécutent que s'ils l'ajoutent eux-mêmes.
- Le bundle doit être régénéré, sinon `tests/run.sh` échoue sur le miroir des scripts.
- `.devloop.conf` est contractuel : sans `contract: approved`, l'intégration est refusée.

## Notes / decisions

- 2026-10-27: le plafond de 150 lignes est codé dans le script, pas dans la configuration, pour
  qu'une branche ne puisse pas le relever sans modifier le script lui-même.
- 2026-10-27: adoption opt-in côté kit (le script est livré, `CHECK_LINT` de l'exemple n'est pas
  modifié) pour ne pas casser les dépôts déjà installés.
- 2026-10-27: `harness-check.sh` est écrit en Bash pur, sans dépendance hors `grep`, `sort`, `wc`.
