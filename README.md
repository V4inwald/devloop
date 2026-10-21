# devloop — une boucle de développement vérifiable pour agents

Ce dépôt contient un dispositif complet, mais volontairement minimal, pour faire travailler des
agents sur un projet **long** : commits lisibles, tests obligatoires, revue indépendante avant
merge, et mémoire versionnée qui survit aux sessions.

L'idée directrice : un agent qui dit « c'est fait » ne prouve rien. Le dispositif transforme
cette affirmation en deux artefacts liés au commit : un résultat de gate et un verdict de revue.
`integrate.sh` refuse de fusionner sans les deux.

## Démarrage rapide

```bash
# 1. copier le kit dans votre dépôt (AGENTS.md, .agents/, scripts/, .githooks/, .github/, docs/)
# 2. adapter les commandes de vérification
cp .devloop.conf.example .devloop.conf && $EDITOR .devloop.conf
# 3. installer les hooks (non versionnables)
bash scripts/devloop/install-hooks.sh
# 4. vérifier que tout est cohérent
bash scripts/devloop/doctor.sh
```

Première tâche :

```bash
git switch -c task/001-ma-tache
# écrire docs/tasks/001-ma-tache.md, puis coder
bash scripts/devloop/gate.sh
bash scripts/devloop/packet.sh          # donner ce fichier au reviewer
# le reviewer écrit docs/reviews/001-ma-tache-r1.md
git add docs/reviews && git commit -m "docs(reviews): approve task-001"
bash scripts/devloop/gate.sh            # HEAD a bougé
bash scripts/devloop/integrate.sh --task task-001
```

## Ce que fait chaque script

| Script | Rôle | Refuse quand |
|---|---|---|
| `gate.sh` | exécute les `CHECK_*` de `.devloop.conf`, écrit un JSON lié au SHA | une commande échoue, ou arbre sale (marqué non intégrable) |
| `packet.sh` | construit le paquet de revue (commits, diff, preuve de gate) | jamais (avertit si le diff est trop gros) |
| `integrate.sh` | fusionne la branche de tâche dans `main` | gate absent/échoué/sale, revue absente ou périmée, diff trop gros, CI rouge |
| `policy.sh` | vérifie messages de commit, secrets, affaiblissement des tests | violation (utilisé en CI, non contournable par `--no-verify`) |
| `doctor.sh` | diagnostic lecture seule de l'état du dépôt | erreur de preuve ou d'état |
| `install-hooks.sh` | installe `core.hooksPath` et exclut `.devloop/` localement | — |

## Mémoire : où mettre quoi

| Couche | Fichier | Chargée | Contenu |
|---|---|---|---|
| chaude | `AGENTS.md` | chaque requête (natif DSH) | règles stables, carte mémoire |
| procédurale | `.agents/skills/*/SKILL.md` | sur demande | étapes, rubriques, formats |
| état / histoire | `docs/STATE.md`, `docs/tasks/`, `docs/adr/`, `docs/reviews/`, `docs/LESSONS.md`, git | à la demande | vérité datée et décisions |
| rappel | mémoire DSH (scope projet) | injectée | pointeurs courts, pas de contenu |

Détail et règles d'écriture : `design/03-memory.md`.

## Ce qui est vérifié dans ce dépôt

- `bash tests/run.sh` : **29 assertions, 0 échec**. Le test crée un dépôt jetable, installe le
  kit, et vérifie les refus réels : commit hors convention, absence de revue, revue pour un SHA
  inconnu, revue invalidée par un commit de code, arbre sale, diff trop gros, gate rouge, push
  direct sur `main`, push non fast-forward, `--no-verify` rattrapé par `policy.sh`.
- Les trois skills de `.agents/skills/` sont apparus dans le catalogue de la session DSH sans
  redémarrage : la découverte de skills telle que décrite par `dsh-skill-filesystem` fonctionne.
- `AGENTS.md` racine est bien injecté comme consignes de l'espace de travail.
- Le workflow GitHub Actions **n'a pas été exécuté** : aucun remote, `gh` non authentifié.

## Limites assumées

- Un agent disposant des droits d'écriture peut écrire un faux `approve`. La défense est la
  séparation de contexte, la trace versionnée, et le contrôle humain — pas une signature.
- Un gate vert prouve que les tests configurés passent, pas que le logiciel est correct.
- Les hooks git sont locaux : après un clone, il faut relancer `install-hooks.sh`. La CI est
  l'arbitre qui ne peut pas être contourné par `--no-verify`.
- Le dispositif est optimisé pour 1 à 3 tâches simultanées ; au-delà, la coordination des
  worktrees devient le goulot.
- Le kit ne fournit pas de tests d'intégration : ajoutez `CHECK_INTEGRATION="..."` quand le
  projet a une base ou un service à démarrer.

## Documentation

- `design/01-architecture.md` — principes, rôles, artefacts, coûts.
- `design/02-dsh-mapping.md` — ce que DSH fournit (vérifié), ce qui manque, comment packager.
- `design/03-memory.md` — les quatre couches et leurs règles d'écriture.
- `design/04-gates-and-review.md` — contrat exact, problème circulaire du SHA, contournements.
- `design/05-risks.md` — 15 défaillances, signaux, risques résiduels, métriques.
- `design/06-roadmap.md` — phases, critères d'acceptation, non-objectifs.
- `docs/adr/0001-adopt-devloop.md` — la décision d'adopter ce contrat.

## Historique git

L'historique de ce dépôt est un **bootstrap** : il est daté d'avant l'adoption du contrat, avec
des commits conventionnels et une branche de tâche, mais sans revue indépendante. Le premier
changement post-bootstrap doit suivre la boucle complète.
