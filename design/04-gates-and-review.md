# 04 — Gates et revue : le contrat exact

## Gate

**Entrée** : HEAD, un arbre de travail, et `.devloop.conf`.

**Sortie** : `.git/devloop/gate/<sha>/result.json`

```json
{
  "sha": "<commit testé>",
  "branch": "task/001-...",
  "task": "task-001",
  "dirty": false,
  "ok": true,
  "checks": [
    { "name": "TEST", "cmd": "node --test", "exit": 0, "seconds": 3 }
  ],
  "generated_at": "2026-10-21T13:33:31Z"
}
```

**Règles**

1. Un gate sur arbre sale est marqué `dirty: true` et **n'est pas intégrable**. Sinon, on pourrait
   tester un état qui n'existe pas dans l'historique.
2. `ok` est la conjonction des codes de sortie. Aucune auto-évaluation, aucun parsing de sortie.
3. Zéro commande configurée = erreur, pas succès silencieux. Un gate vide est un mensonge.
4. La CI exécute **le même script**. Deux définitions de « vert » = aucune vérité.
5. Les logs restent locaux ; seul le JSON est lu par la suite du pipeline.

## Revue

**Entrée** : le paquet de revue (`packet.sh`) + le fichier de tâche + le dépôt au SHA revu.

**Sortie** : `docs/reviews/<task>-r<N>.md`, versionné.

```yaml
---
task: task-001
sha: <sha exact>
verdict: approve | revise | reject
blockers: 0
reviewer: <nom ou self>
date: YYYY-MM-DD
---
```

**Règles**

1. `approve` exige `blockers: 0` **et** une ligne de preuve par item de rubrique. Un tableau vide
   n'est pas une revue.
2. Le reviewer ne modifie pas le code. Il peut exécuter des commandes.
3. Deux rounds maximum. Au-delà, escalade humaine avec la liste des bloqueurs.
4. Un fichier de revue est immuable après commit. Changer d'avis = round suivant.
5. `reviewer: self` est autorisé en mode solo, mais exige une approbation humaine avant
   intégration.

## Le problème circulaire (et sa solution)

Écrire le verdict dans le dépôt crée un nouveau commit, donc un nouveau SHA. Le verdict ne peut
donc pas nommer le SHA qui le contient.

Solution retenue : le verdict nomme le SHA **revu**, et l'intégrateur tolère que les seuls commits
postérieurs soient des ajouts sous `docs/reviews/`. Tout autre changement invalide la revue.

```
S1 = code revu          → verdict sha: S1
S2 = S1 + docs/reviews  → HEAD, gate relancé sur S2
integrate(S2) : vérifie gate(S2) et revue(S1) ; S1→S2 ne touche que docs/reviews/
```

Conséquences :

- après avoir commité le verdict, il faut **relancer le gate** (HEAD a bougé) ;
- un changement de code après revue est détecté, pas silencieusement accepté ;
- l'enregistrement d'intégration distingue `reviewed_sha` (S1) et `head_sha` (S2).

C'est un détail qui paraît mineur et qui casse tout s'il est ignoré : la plupart des boucles
« revue puis merge » échouent ici, soit en approuvant un SHA périmé, soit en réécrivant le verdict.

## Anti-tampon

| Mesure | Ce qu'elle empêche |
|---|---|
| reviewer = contexte séparé | auto-approbation déguisée |
| rubrique avec preuve par item | « looks good to me » |
| test de régression vérifié par revert | test qui passe avec ou sans le correctif |
| plafond de deux rounds | boucle de revue infinie et théâtrale |
| `reviewer: self` visible | fausse indépendance |
| vérification des assertions supprimées (policy) | affaiblissement des tests |
| diff plafonné | revue impossible car trop gros |

## Ce que le gate ne peut pas voir

- un test qui vérifie la mauvaise chose ;
- une conception qui ne répond pas au besoin ;
- un comportement en production (réseau, concurrence, données réelles).

## Ce que la revue ne peut pas voir

- ce qui n'est pas dans le diff (un fichier oublié) ;
- un bug qui ne se manifeste qu'à l'exécution ;
- une décision produit non écrite.

C'est pourquoi la CI, les tests d'intégration, et un humain sur les zones sensibles restent
nécessaires. Le dispositif rend la fraude visible ; il ne rend pas le logiciel correct.

## Le merge est gaté, pas seulement la branche

Une branche peut passer ses tests et casser le résultat du merge (conflit sémantique). Depuis
task-002, `integrate.sh` construit le merge dans un worktree détaché, exécute le gate **sur le
commit de merge**, et ne déplace `main` que si ce résultat est vert. Un échec laisse `main`
intact. Les intégrations sont sérialisées par un verrou ; le commit de merge porte
`Reviewed-by:`, `Reviewed-blob:` et `Gate:`.

## GitHub arbitre (protection de branche)

Sur un dépôt protégé (`REQUIRE_PR=true`), `integrate.sh --pr` pousse la branche, ouvre une PR,
attend le check requis `gate`, merge via `gh pr merge`, puis gate le commit de merge GitHub
localement avant de synchroniser `main`. `protect.sh` applique la protection : check `gate`
requis, `enforce_admins`, pas de force-push ni de suppression ; `strict:false` car la CI de
PR teste déjà le commit de merge (`refs/pull/N/merge`). Le push direct sur `main` est refusé,
y compris pour l'admin : le bookkeeping (`STATE.md`/`LESSONS.md`) passe par une PR
`state/<sha>`. Avec un seul compte GitHub, `REQUIRED_APPROVALS=0` (auto-approbation
impossible) ; la revue versionnée dans `docs/reviews/` reste le gate de processus.

## Contournements et réponses

| Contournement | Réponse |
|---|---|
| `git commit --no-verify` | `policy.sh` en CI revalide chaque message |
| `git push --no-verify` sur main | branch protection côté serveur (à activer) |
| éditer `result.json` | artefact local régénéré ; `doctor` vérifie le `.sha`, et `integrate.sh` gate aussi le merge |
| écrire un faux `approve` | rien ne l'empêche techniquement ; séparation de contexte, trace, échantillonnage humain |
| vider `.devloop.conf` | modification visible en diff, revue ; la CI échoue si zéro check |
| `integrate.sh --allow-oversized` | visible dans l'historique de commande et le diff |

Le dernier point est une limite assumée : un agent avec les droits d'écriture peut mentir. Le
système ne prétend pas l'empêcher ; il rend le mensonge coûteux, daté et vérifiable.
