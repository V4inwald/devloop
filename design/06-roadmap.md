# 06 — Feuille de route

Les phases sont ordonnées par **preuve d'abord** : on n'ajoute de l'automatisation qu'après avoir
mesuré la phase précédente. Chaque phase a un critère d'acceptation vérifiable.

## Phase 0 — Kit et preuve locale (fait)

Livré dans ce dépôt :

- contrat chaud (`AGENTS.md`), trois skills (`dev-cycle`, `code-review`, `task-authoring`) ;
- `gate.sh`, `packet.sh`, `integrate.sh`, `policy.sh`, `doctor.sh`, `install-hooks.sh` ;
- hooks `commit-msg` et `pre-push`, workflow CI qui exécute le même gate ;
- gabarits tâche / revue / ADR, `STATE.md`, `LESSONS.md` ;
- suite de tests bout-en-bout.

**Critère atteint** : `bash tests/run.sh` → 29 assertions, 0 échec, dont les refus (absence de
revue, revue périmée, arbre sale, diff trop gros, push sur `main`, commit hors convention).

## Phase 1 — Adoption sur un vrai dépôt (1 à 2 semaines)

1. Copier le kit, adapter `.devloop.conf` aux commandes réelles.
2. Lancer `install-hooks.sh`, faire une première tâche courte.
3. Activer la protection de branche et les checks requis dans la CI.
4. Faire 3 tâches complètes, dont une qui échoue en revue puis se corrige.

**Critère** : 3 revues versionnées existent, au moins une contient un bloqueur, et le taux de
gate vert au premier essai est mesuré (pas supposé).

## Phase 2 — Durcissement (2 à 4 semaines)

- `gitleaks` ou équivalent dans la CI, en plus de la regex de `policy.sh` ;
- seuil de couverture sur les modules critiques, pas global ;
- test de mutation sur le cœur métier (au moins manuel) ;
- `CODEOWNERS` sur les zones sensibles, checks requis ;
- `gh` authentifié, `REQUIRE_CI=true` dans `integrate.sh` ;
- script de rapport : revues, bloqueurs, délais, échecs de gate.

**Critère** : une CI rouge ne peut pas être mergée ; un secret introduit volontairement est
bloqué ; le rapport se génère sans intervention manuelle.

## Phase 3 — Empaquetage DSH (1 semaine)

Objectif : que la procédure se déclenche sans être rappelée.

- un preset d'agent « devloop » (`@deepseek-ai/dsh-agent-preset` : `id`, liste de plugins) qui
  monte skills + outils d'équipe + consignes ;
- éventuellement un plugin mince exposant `devloop_gate` / `devloop_integrate` en outils
  structurés, pour les cas où le shell libre n'est pas souhaitable ;
- une commande `/dev-cycle` qui ouvre la procédure et le preset.

**Critère** : une session neuve dans le dépôt exécute la boucle complète sans qu'on lui
explique les commandes, et échoue proprement si les preuves manquent.

## Phase 4 — Multi-agents (2 à 3 semaines)

- un worktree par tâche, sous-agents avec `cwd` dédié ;
- reviewer en sous-agent systématique, jamais le même contexte que l'implémenteur ;
- coordinateur qui limite le parallélisme à 2–3 tâches et sérialise les intégrations ;
- mirroring board d'équipe → `docs/tasks/` (le board n'est pas durable).

**Critère** : deux tâches menées en parallèle, deux revues indépendantes, aucune collision de
fichiers, intégrations séquentielles sans conflit manuel.

## Phase 5 — Gouvernance (continu)

- plafonds de coût par tâche et par jour, avec arrêt automatique ;
- gates humains sur les chemins protégés (auth, paiements, migrations, CI, secrets) ;
- post-mortems d'incidents convertis en ADR ;
- revue trimestrielle de `AGENTS.md` : supprimer ce qui n'est plus vrai.

**Critère** : un dépassement de budget arrête le travail au lieu de le ralentir ; chaque incident
majeur a un ADR associé.

## Non-objectifs

- Remplacer la décision produit ou l'arbitrage de risque par un agent.
- Garantir zéro bug : le dispositif rend la fraude visible, il ne prouve pas la correction.
- Supporter des dizaines d'agents en parallèle : le coût de coordination dépasse le gain avant.
- Construire un plugin avant d'avoir mesuré que les scripts ne suffisent pas.

## Ordre de priorité si le temps manque

1. Gate + intégration qui refusent (le cœur).
2. Revue indépendante versionnée (la différence avec « l'agent dit que c'est bon »).
3. `STATE.md` + ADR (la reprise sans contexte).
4. CI (l'arbitre non contournable).
5. Le reste (preset, plugin, multi-agents) est un accélérateur, pas une fondation.
