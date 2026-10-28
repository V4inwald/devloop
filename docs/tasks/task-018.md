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
- [ ] AC6 (r3): le mode fusionné ne pousse pas la branche (assertion `ls-remote` dans le test).
- [ ] AC7 (r3): un merge à un seul parent (squash) est refusé (test dédié).
- [ ] AC8 (r4): main avance d'un commit de contrat après le fork → aucun faux refus, `base` = point
      de fork, `diff_lines` exclut les lignes de main (test).
- [ ] AC9 (r4): contrat refusé en mode fusionné sans `contract: approved`, aucun record (test).
- [ ] AC10 (r4): taille refusée en mode fusionné, aucun record (test).
- [ ] AC11 (r4): aucun record pour un squash refusé ; `doctor.sh` sort 0 après enregistrement (tests).
- [ ] AC12 (r4): une seule fonction `check_contract_and_size`, appelée par les deux voies.

## Scope

Touched: `scripts/devloop/integrate.sh`, son miroir `dist/devloop-skill/assets/`, `tests/run.sh`,
`README.md`, `docs/tasks/task-018.md`.
Out of scope: `gate.sh`, `doctor.sh`, `.devloop.conf`, `AGENTS.md`, le mode local d'intégration.

## Verification plan

1. `bash tests/run.sh` — 157 assertions, dont la section « owner-merged pr » et les cinq tests r4.
2. `bash scripts/devloop/gate.sh` sur arbre propre.
3. Après merge : `doctor.sh` ne dit plus « not an integration merge » sur `main`.

## Risks

- Détection trop large : on exige `reviewDecision` APPROVED (ou vide), un head identique à HEAD et
  un merge à deux parents.
- Contrat et taille passent par une seule fonction `check_contract_and_size`, appelée par la voie
  normale et par la voie fusionnée, avec `BASE` = point de fork.
- 2026-10-28 (r3): le owner a demandé sur PR #20 l'assertion « sans push » et le test du merge à un
  seul parent ; le message du commit 8c61838 les annonçait à tort. AC4 (148) décrit la r2 ; la
  suite compte 150 en r3. Ronde 3 explicitement autorisée par le owner.
- 2026-10-28 (r4): le owner a demandé `BASE = merge-base(SHA, <merge>^1)`, la factorisation du
  contrôle et cinq tests. Le diff projet fait 489 lignes : dépassement de `MAX_DIFF_LINES`
  explicitement autorisé par le owner, intégration prévue avec `--allow-oversized`.
