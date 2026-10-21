# 0002 — Statut des tâches et bookkeeping sous protection

- Status: accepted
- Date: 2026-10-21
- Deciders: lead
- Task: task-009

## Context

La règle de bookkeeping ne couvrait que `docs/STATE.md` et `docs/LESSONS.md`. Après une
intégration, le fichier de tâche restait donc en `status: review` indéfiniment, alors que la
définition de « terminé » exige `status: done` et des critères cochés. Depuis le passage en
public, `main` est protégé et un push direct est refusé : le bookkeeping doit passer par une PR.

## Decision

Après une intégration réussie, l'intégrateur peut mettre à jour, dans le même changement de
bookkeeping que `STATE.md`/`LESSONS.md` :

- le `status` du fichier de tâche (`review` → `done`) ;
- les cases des critères d'acceptation déjà démontrés.

Le texte des critères n'est **jamais** réécrit. Quand `main` n'est pas protégé, le changement
est un commit direct `chore(state):` ; quand il l'est, il passe par une PR `state/<sha>` avec le
check `gate`. Le code et les tests restent hors de cette exception.

## Consequences

**Positive**

- Les tâches se ferment réellement ; `STATE.md` et les fichiers de tâche racontent la même histoire.
- La protection de `main` reste intacte : le bookkeeping suit le flux PR.

**Negative / coûts acceptés**

- Le fichier de tâche n'est plus strictement immuable dans son statut ; seul le texte des
  critères reste immuable.
- Une PR de plus par intégration (quelques secondes de CI).

**Neutre**

- La revue de code continue de couvrir le SHA revu, indépendamment du statut de la tâche.

## Alternatives considérées

| Alternative | Pourquoi pas |
|---|---|
| Laisser les tâches en `review` | La définition de « terminé » devient fausse et `doctor`/STATE divergent |
| Autoriser un push direct de bookkeeping malgré la protection | Contourne la barrière serveur que tout le reste protège |
| Créer une tâche de suivi par clôture | Coût de cérémonie sans valeur |

## Follow-up

- Si le projet abandonne la protection, la branche « commit direct » de la décision reste valable.
