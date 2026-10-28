---
id: task-017
status: done
branch: task/017-harness-probes
created: 2026-10-27
owner: lead
implementer: lead
---

# Sondes du harness et décision d'architecture

## Outcome

`docs/harness/PROBES.md` fixe six sondes comportementales avec leur baseline datée, et l'ADR 0003
enregistre la décision d'adopter la boucle Harness² adaptée, ses conséquences et ses alternatives.

## Acceptance criteria

- [x] AC1: `docs/harness/PROBES.md` contient six sondes avec colonnes PASS et FAIL, plus les
      variantes durcies et la section baseline.
- [x] AC2: la baseline nomme le SHA `8e2e254`, les résultats P1-P3 et la limite honnête
      (« ces sondes ne démontrent pas un défaut actuel »).
- [x] AC3: `docs/adr/0003-harness-improvement-loop.md` porte `Statut : accepted` et les sections
      Contexte, Décision, Conséquences, Alternatives écartées.
- [x] AC4: les deux chemins cités dans `docs/harness/PROBES.md` existent
      (`test -f .githooks/commit-msg && test -f scripts/devloop/policy.sh`).
- [x] AC5: `bash scripts/devloop/gate.sh` sort 0 sur un arbre propre.
- [x] AC6: une revue indépendante approuve ce SHA.

## Scope

Touched: `docs/harness/PROBES.md`, `docs/adr/0003-harness-improvement-loop.md`,
`docs/tasks/task-017.md`.

Out of scope: `AGENTS.md`, `.agents/skills/**`, `scripts/**`, `.devloop.conf`, `README.md`.

## Verification plan

1. `test -f .githooks/commit-msg && test -f scripts/devloop/policy.sh` → exit 0.
2. `bash scripts/devloop/gate.sh` sur arbre propre.
3. Revue indépendante (documentaire).

## Risks

- Une sonde vague ne mesure rien : chaque ligne doit tenir en un prompt et un observable.
- La baseline est qualitative et déjà verte sur P1-P3 ; le document doit le dire, pas le maquiller.
- Aucun risque d'exécution : changement documentaire uniquement.

## Notes / decisions

- 2026-10-27: la baseline P1-P3 a été exécutée par un agent frais avant task-015, à `8e2e254` ;
  P4-P6 sont documentées mais non jouées (coût).
- 2026-10-27: l'ADR référence les trois tâches ; il est accepté après leur implémentation, ce qui
  est autorisé (l'ADR n'est pas rétroactif sur les critères d'acceptation).
