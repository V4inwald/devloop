---
id: task-018
status: review
branch: task/018-record-owner-merge
created: 2026-10-28
owner: lead
implementer: lead
---

# Enregistrer une PR fusionnée par le owner

## Outcome

Quand le owner fusionne une PR depuis l'interface GitHub, relancer `integrate.sh --task <id> --pr`
reconstruit l'enregistrement d'intégration (gate du merge rejoué, revue et contrat vérifiés) au lieu
d'ouvrir une seconde PR ; `doctor.sh` certifie ensuite `main`.

## Acceptance criteria

- [ ] AC1: sur une PR fusionnée dont le head est HEAD, `integrate.sh --task <id> --pr` écrit
      `$ART/integrations/<merge>.json` avec `head_sha` = HEAD et `base` = `<merge>^1`, sans pousser
      ni créer de PR (test avec faux `gh`).
- [ ] AC2: si le head de la PR diffère de HEAD, la commande refuse et n'écrit rien (test).
- [ ] AC3: en mode fusionné, contrat et taille sont recalculés sur `<merge>^1..HEAD` ; une branche
      touchant un chemin de contrat sans `contract: approved` est refusée (même code que la voie
      normale, vérifié en revue).
- [ ] AC4: `bash tests/run.sh` passe (148 assertions) et `gate.sh` sort 0 sur arbre propre.
- [ ] AC5: revue indépendante approuve ce SHA avec `contract: approved` (`scripts/devloop` touché).

## Scope

Touched: `scripts/devloop/integrate.sh`, son miroir `dist/devloop-skill/assets/`, `tests/run.sh`,
`README.md`, `docs/tasks/task-018.md`.
Out of scope: `gate.sh`, `doctor.sh`, `.devloop.conf`, `AGENTS.md`, le mode local d'intégration.

## Verification plan

1. `bash tests/run.sh` — section « owner-merged pr » (6 assertions).
2. `bash scripts/devloop/gate.sh` sur arbre propre.
3. Après merge : `doctor.sh` ne dit plus « not an integration merge » sur `main`.

## Risks

- Détection trop large : on exige `reviewDecision` APPROVED (ou vide), un head identique à HEAD et
  un merge à deux parents.
- La factorisation contrat/taille est rejouée sur la bonne base ; les tests existants couvrent les
  refus de la voie normale.
