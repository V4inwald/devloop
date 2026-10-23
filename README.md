# devloop — une boucle de développement vérifiable pour agents

Ce dépôt contient un dispositif complet, mais volontairement minimal, pour faire travailler des
agents sur un projet **long** : commits lisibles, tests obligatoires, revue indépendante avant
merge, et mémoire versionnée qui survit aux sessions.

L'idée directrice : un agent qui dit « c'est fait » ne prouve rien. Le dispositif transforme
cette affirmation en deux artefacts liés au commit : un résultat de gate et un verdict de revue.
`integrate.sh` refuse de fusionner sans les deux.

## Démarrage rapide

```bash
# 1. voir ce que l'installateur ferait, puis l'installer (non destructif)
bash dist/devloop-skill/install.sh --dry-run
bash dist/devloop-skill/install.sh
# 2. adapter les commandes de vérification
$EDITOR .devloop.conf
# 3. vérifier que tout est cohérent
bash scripts/devloop/doctor.sh
```

L'installateur refuse d'écraser un fichier existant sans `--force` (sauvegarde sous
`<git-common-dir>/devloop/backup-*`), ne supprime jamais un hook/script inconnu, et installe le
workflow sous `.github/workflows/devloop-ci.yml` pour ne pas clobber un `ci.yml` existant.

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
| `gate.sh` | exécute les `CHECK_*`, écrit un JSON lié au SHA dans `<git-common-dir>/devloop` | une commande échoue (exit 1), ou arbre sale (exit 3, `UNVERIFIED`) |
| `packet.sh` | construit le paquet de revue (commits, diff, preuve de gate) | jamais (avertit si le diff est trop gros) |
| `integrate.sh` | fusionne dans un worktree détaché, **gate le merge**, puis avance `main` | contrat de tâche absent/incohérent, gate/revue absents ou périmés, revue modifiée, contrat non approuvé, diff trop gros, CI rouge, merge gate rouge |
| `policy.sh` | vérifie messages de commit, secrets, affaiblissement des tests | violation (utilisé en CI, non contournable par `--no-verify`) |
| `doctor.sh` | diagnostic lecture seule de l'état du dépôt | erreur de preuve ou d'état |
| `install-hooks.sh` | installe `core.hooksPath` et exclut `.devloop/` localement | — |
| `prove-red.sh` | copie les tests modifiés dans un worktree au commit de base et vérifie qu'ils échouent sans le correctif | le test passe sur la base (ce n'est pas un test de régression) |

## Mémoire : où mettre quoi

| Couche | Fichier | Chargée | Contenu |
|---|---|---|---|
| chaude | `AGENTS.md` | chaque requête (natif DSH) | règles stables, carte mémoire |
| procédurale | `.agents/skills/*/SKILL.md` | sur demande | étapes, rubriques, formats |
| état / histoire | `docs/STATE.md`, `docs/tasks/`, `docs/adr/`, `docs/reviews/`, `docs/LESSONS.md`, git | à la demande | vérité datée et décisions |
| rappel | mémoire DSH (scope projet) | injectée | pointeurs courts, pas de contenu |

Détail et règles d'écriture : `design/03-memory.md`.

## Ce qui est vérifié dans ce dépôt

- `bash tests/run.sh` : **135 assertions, 0 échec**. Le test crée un dépôt jetable, installe le
  kit, et vérifie les refus réels : commit hors convention, absence de revue, revue pour un SHA
  inconnu, revue invalidée par un commit de code, arbre sale, diff trop gros, gate rouge, push
  direct sur `main`, push non fast-forward, `--no-verify` rattrapé par `policy.sh`.
- Les trois skills de `.agents/skills/` sont apparus dans le catalogue de la session DSH sans
  redémarrage : la découverte de skills telle que décrite par `dsh-skill-filesystem` fonctionne.
- `AGENTS.md` racine est bien injecté comme consignes de l'espace de travail.
- Le workflow GitHub Actions **a été exécuté** sur le dépôt privé
  `https://github.com/V4inwald/devloop` : gate, policy `--strict` et upload d'artefacts verts.

## GitHub arbitre

Quand `REQUIRE_PR=true` :

```bash
bash scripts/devloop/protect.sh   # gate requis, admins inclus, pas de force-push
bash scripts/devloop/integrate.sh --task <id> --pr
```

`--pr` pousse la branche, ouvre/retrouve la PR, attend le check requis `gate`, merge via
`gh pr merge`, **gate le commit de merge GitHub localement**, puis synchronise `main`. Le
bookkeeping (`STATE.md`, `LESSONS.md`) passe par une courte PR `state/<sha>`. Avec un seul
compte GitHub, aucune approbation GitHub n'est exigée (on ne peut pas approuver sa propre PR) ;
la revue fichier `docs/reviews/` reste le gate de processus.

**Revue owner** : la protection exige **1 approbation**. L'agent `comptetest101` ouvre la PR,
le check `gate` passe, puis `integrate.sh --pr` s'arrête sur `REVIEW_REQUIRED` ; le reviewer
(l'humain ou l'agent isolé du container `.reviewer/`) approuve, et l'agent relance `--pr` pour
merger. Le modèle d'identité et l'isolation sont dans
[`docs/security/identity-model.md`](docs/security/identity-model.md).

**Limite du plan** : GitHub Free ne fournit pas branch protection ni rulesets sur un dépôt
**privé**. `protect.sh` le détecte et explique les options. En privé sur Free, `main-guard`
détecte (issue + job rouge) un push direct sur `main` : c'est une **détection, pas une
prévention**. La prévention réelle exige un dépôt public ou GitHub Pro/Team. Si le dépôt passe
en public, `protect.sh` devient la barrière et `main-guard` reste une ceinture de sécurité.

## Publication

Ce dépôt est un **outil** : il est destiné à être public (licence MIT, politique de sécurité
dans `SECURITY.md`), tandis que les projets qui l'utilisent restent privés. Le dépôt a été
audité avant publication (`docs/security/pre-public-audit.md`) : aucun secret dans l'historique.
Après le passage en public, `protect.sh` applique la protection de `main` et GitHub active le
secret scanning + push protection. L'authentification du workspace reste **hors du dépôt** ;
ne jamais commiter `.gh`, `.github-env`, `.env` ou une clé.

## Limites assumées

- Un agent disposant des droits d'écriture peut écrire un faux `approve`. La défense est la
  séparation de contexte, la trace versionnée, et le contrôle humain — pas une signature.
- Un gate vert prouve que les tests configurés passent, pas que le logiciel est correct.
- Les hooks git sont locaux : après un clone, il faut relancer `install-hooks.sh`. La CI est
  l'arbitre qui ne peut pas être contourné par `--no-verify`.
- Le dispositif est optimisé pour 1 à 3 tâches simultanées ; au-delà, la coordination des
  worktrees devient le goulot. Un seul intégrateur à la fois (verrou), un écrivain par worktree.
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
