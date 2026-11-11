---
task: task-019
sha: 99cc11df5656c25a246cf45e4fbfe9f35d645c29
verdict: approve
blockers: 0
reviewer: independent-proof-reviewer
contract: approved
date: 2026-11-11
---

# Revue indépendante — task-019, round 1

## Périmètre et décision

Sources de vérité : [contrat task-019](</workspace/devloop-019-proof-integrity/docs/tasks/task-019.md>) et [paquet de revue](</workspace/Improvement/.git/devloop/review/99cc11df5656c25a246cf45e4fbfe9f35d645c29-packet.md>). Base : `4f0ebbd56572a828c064bbce139bed47da2833a5`. HEAD constaté avant et après les contrôles : `99cc11df5656c25a246cf45e4fbfe9f35d645c29`, branche `task/019-proof-integrity`, dépôt source propre avant la création de cette revue.

**Approve, zéro blocker.** Le gate conserve le SHA initial, relit HEAD et l'état suivi/non suivi/indexé après les checks, conserve une saleté initiale même nettoyée, et rend non intégrable un déplacement de HEAD via `ok=false`. Les checks échoués gardent la priorité du code 1 ; les checks réussis avec état invalide sortent 3. Le lint remplace l'appel multi-arguments inefficace par un appel `bash -n` par fichier, avec tableau cité pour préserver les espaces. Le nouveau test est effectivement branché au gate et les deux scripts distribués sont identiques aux sources.

L'approbation du contrat couvre ces changements dans [.devloop.conf:2–3](</workspace/devloop-019-proof-integrity/.devloop.conf#L2-L3>), [gate.sh:59–94](</workspace/devloop-019-proof-integrity/scripts/devloop/gate.sh#L59-L94>) et [lint-shell.sh:1–10](</workspace/devloop-019-proof-integrity/scripts/devloop/lint-shell.sh#L1-L10>). Les seuils, protections, modes PR/CI et règles d'intégration ne sont pas assouplis.

## Contrôles exécutés et preuves liées au SHA

Chaque invocation de commande git ou de script utilisant git/gh a été précédée de `source /workspace/.github-env`. Aucun accès réseau. Les exécutions de tests et leurs opérations Git de fixtures ont eu lieu uniquement dans des dépôts temporaires ; aucun commit, push, merge ni changement de code/test/configuration du dépôt examiné. La seule écriture dans ce dépôt est cette revue non commitée.

### 1. Gate complet rejoué indépendamment

Copie locale distincte, créée par `git clone --quiet --local --no-hardlinks --single-branch --branch task/019-proof-integrity`, avec contrôle du SHA et de la propreté. `GIT_ALLOW_PROTOCOL=file`, `GIT_TERMINAL_PROMPT=0` et suppression des overrides `DEVLOOP_ARTIFACTS`, `DEVLOOP_CONF`, `DEVLOOP_LEGACY_ARTIFACTS` avant le gate. Dans ce clone :

```text
bash scripts/devloop/gate.sh --task task-019
LINT PASS, exit 0
TEST PASS, exit 0
passed: 142, failed: 0
proof integrity: 24 passed, 0 failed
gate_exit=0; HEAD inchangé; clone toujours propre
```

[Résultat indépendant](</tmp/devloop-task019-review.DGB9SC/reviewed/.git/devloop/gate/99cc11df5656c25a246cf45e4fbfe9f35d645c29/result.json>), [journal TEST:204–238](</tmp/devloop-task019-review.DGB9SC/reviewed/.git/devloop/gate/99cc11df5656c25a246cf45e4fbfe9f35d645c29/TEST.log#L204-L238>) et [journal LINT](</tmp/devloop-task019-review.DGB9SC/reviewed/.git/devloop/gate/99cc11df5656c25a246cf45e4fbfe9f35d645c29/LINT.log>) relus. Les liens temporaires ne constituent pas une garantie de conservation ; les résultats essentiels sont consignés ici :

```json
{
  "sha": "99cc11df5656c25a246cf45e4fbfe9f35d645c29",
  "branch": "task/019-proof-integrity",
  "task": "task-019",
  "dirty": false,
  "ok": true,
  "head_after": "99cc11df5656c25a246cf45e4fbfe9f35d645c29",
  "head_changed": false,
  "generated_at": "2026-11-11T03:09:22Z"
}
```

Extrait du JSON, avec les sorties LINT/TEST détaillées ci-dessus. Le [résultat partagé d'origine](</workspace/Improvement/.git/devloop/gate/99cc11df5656c25a246cf45e4fbfe9f35d645c29/result.json>) a également été lu : mêmes SHA, flags et codes de checks, génération `2026-11-11T03:05:59Z`. Il n'a pas été réécrit par le reviewer.

### 2. Régression réellement rouge sur la référence

Archive temporaire de `4f0ebbd56572a828c064bbce139bed47da2833a5` via `git archive`, avec uniquement le nouveau test recopié dans cette archive. Exécution de `bash tests/proof-integrity.sh` sur cette référence : **exit 1, 6 assertions réussies et 14 échouées**. Les refus attendus manquent pour les mutations suivies/non suivies/indexées et le déplacement de HEAD ; les deux SHA ne sont pas enregistrés ; le helper lint n'existe pas. Il ne s'agit donc pas d'un simple échec de lancement. Le parent direct `78a520a6990ae9b7c8c1e3418231be87bc1ecb9f` a le même contenu que la base pour les scripts, tests et configuration concernés : `git diff --exit-code <base> <parent> -- scripts/devloop .devloop.conf tests` → 0.

Contre-exemple indépendant du lint antérieur :

```bash
bash -n <(printf 'echo valid\n') <(printf 'if\n')
```

→ exit 0 malgré le deuxième script invalide. Au SHA relu, le nouveau test exige exit 2 et le nom du fichier fautif pour le deuxième script puis le deuxième hook ; après correction des fixtures, l'ensemble valide avec espace dans le nom passe.

### 3. Sondes supplémentaires du reviewer

Quatre scénarios, chacun dans une copie locale isolée partant du SHA relu, avec configuration temporaire externe. Chaque résultat a été contrôlé avec `jq -e` puis relu. Dans les quatre cas, `.sha` reste le SHA relu et `.head_after` est **égal** au véritable `git rev-parse HEAD` final.

| Check de la fixture | Exit gate | `ok` / `dirty` / `head_changed` | Cause conservée |
|---|---:|---|---|
| Modification suivie puis `exit 7` | 1 | false / true / false | `.checks[0].exit=7` |
| Checkout détaché vers le parent direct | 3 | false / false / true | check réussi ; SHA final `78a520a6990ae9b7c8c1e3418231be87bc1ecb9f` |
| Même checkout puis `exit 7` | 1 | false / false / true | `.checks[0].exit=7`, même SHA final |
| `git update-index --chmod=+x .githooks/commit-msg` seulement | 3 | true / true / false | index 100644→100755 ; fichier de travail toujours 644 |

Le dernier résultat reste non intégrable : le lecteur exige conjointement `ok=true` **et** `dirty=false`, et non le seul flag `ok`. Preuves temporaires : [mutation et échec](</tmp/devloop-task019-review.DGB9SC/dirty_failure/.git/devloop/gate/99cc11df5656c25a246cf45e4fbfe9f35d645c29/result.json>), [HEAD déplacé](</tmp/devloop-task019-review.DGB9SC/head_success/.git/devloop/gate/99cc11df5656c25a246cf45e4fbfe9f35d645c29/result.json>), [HEAD déplacé et échec](</tmp/devloop-task019-review.DGB9SC/head_failure/.git/devloop/gate/99cc11df5656c25a246cf45e4fbfe9f35d645c29/result.json>), [index seul](</tmp/devloop-task019-review.DGB9SC/staged_only/.git/devloop/gate/99cc11df5656c25a246cf45e4fbfe9f35d645c29/result.json>).

## Acceptance criteria

| Critère | Preuve et résultat |
|---|---|
| AC1 | [Tests:36–65](</workspace/devloop-019-proof-integrity/tests/proof-integrity.sh#L36-L65>) exécutés : propre→0 ; check échoué→1 avec cause 7 ; quatre mutations avec checks réussis→3, message `UNVERIFIED`, JSON non intégrable ; saleté initiale nettoyée toujours refusée. |
| AC2 | [Gate:61–76](</workspace/devloop-019-proof-integrity/scripts/devloop/gate.sh#L61-L76>) et sondes supplémentaires : SHA initial conservé, SHA final exact, booléen de changement exact. [Lecteur integrate:101–106](</workspace/devloop-019-proof-integrity/scripts/devloop/integrate.sh#L101-L106>) compatible sans modification. |
| AC3 | [Tests:70–83](</workspace/devloop-019-proof-integrity/tests/proof-integrity.sh#L70-L83>) : deuxième script invalide→2 avec nom ; deuxième hook invalide→2 avec nom ; ensemble valide et nom avec espace→0. |
| AC4 | Gate complet : 142 assertions existantes + 24 nouvelles, zéro échec ; [CHECK_TEST:2](</workspace/devloop-019-proof-integrity/.devloop.conf#L2>) appelle les deux suites. `cmp` des deux scripts avec leurs miroirs→0 et assertion de miroir de toute la collection verte. |
| AC5 | Gate indépendant propre pour `99cc11df5656c25a246cf45e4fbfe9f35d645c29`, exit 0 ; présente revue indépendante finale avec `contract: approved`. Aucune validation anticipée d'une future intégration. |

## Evidence — rubrique code-review

| Rubric item | Evidence |
|---|---|
| 1. Acceptance | Les cinq critères sont vérifiés dans la table ci-dessus ; aucun critère laissé sans preuve. |
| 2. Tests | Nouveau [test:36–83](</workspace/devloop-019-proof-integrity/tests/proof-integrity.sh#L36-L83>) exécuté par le gate ; 24/0 au SHA relu, 6/14 et exit 1 sur la production de référence. Le bug du lint multi-arguments est également reproduit indépendamment. |
| 3. Test integrity | `git diff --numstat <base>..<sha>` : nouveau test, 86 ajouts/0 retrait ; aucune modification de la suite existante. Inspection du diff : aucune assertion supprimée/affaiblie, aucun skip, sleep ou délai augmenté. Les nouvelles assertions vérifient codes précis, JSON et diagnostics. |
| 4. Correctness | [Gate:22–25](</workspace/devloop-019-proof-integrity/scripts/devloop/gate.sh#L22-L25>) et [59–94](</workspace/devloop-019-proof-integrity/scripts/devloop/gate.sh#L59-L94>) : capture initiale, saleté persistante, observation finale, refus de HEAD déplacé même propre. Les sondes testent aussi un déplacement vers un commit existant et une mutation d'index seule. [Lint:5–9](</workspace/devloop-019-proof-integrity/scripts/devloop/lint-shell.sh#L5-L9>) cite chaque fichier séparément. |
| 5. Errors | [Gate:44–48](</workspace/devloop-019-proof-integrity/scripts/devloop/gate.sh#L44-L48>) conserve le code original ; [78–94](</workspace/devloop-019-proof-integrity/scripts/devloop/gate.sh#L78-L94>) distingue échec et état non vérifié. Sondes combinées→1 avec `.checks[0].exit=7` ; syntaxe invalide→2 et diagnostic identifiant le fichier. |
| 6. Security | Aucune nouvelle entrée réseau, dépendance ou commande évaluant un nom de fichier. [Lint:7–9](</workspace/devloop-019-proof-integrity/scripts/devloop/lint-shell.sh#L7-L9>) utilise `"${files[@]}"` et `--`. [Nettoyage des nouvelles fixtures:6–10](</workspace/devloop-019-proof-integrity/tests/proof-integrity.sh#L6-L10>) contrôle le chemin canonique/préfixe et protège la variable avant suppression. Checks de confiance, pas sandbox : limite explicitée au contrat. Aucun secret ajouté dans le diff. |
| 7. Compatibility | Champs JSON existants conservés ; deux champs ajoutés. Le [lecteur integrate:101–106](</workspace/devloop-019-proof-integrity/scripts/devloop/integrate.sh#L101-L106>) refuse déjà `ok=false` ou `dirty=true` ; ses scénarios d'intégration et de gate de merge restent verts dans les 142 assertions. Codes 0/1/2/3 préservés, code 3 étendu au HEAD déplacé. |
| 8. Scope | Diff réel = 7 fichiers, 202 ajouts/16 retraits, soit 218 lignes modifiées ; 321 lignes de diff textuel dans le paquet, dans les deux cas sous `MAX_DIFF_LINES=400`. Seulement le périmètre annoncé, miroirs compris ; aucun changement des protections, seuils, intégrateur ou doctor. |
| 9. Readability | [Gate:59–67](</workspace/devloop-019-proof-integrity/scripts/devloop/gate.sh#L59-L67>) nomme explicitement `HEAD_AFTER`/`HEAD_CHANGED` ; helper lint de 10 lignes. `git diff --check <base>..<sha>`→0. Pas de problème sévère de lisibilité. |
| 10. Docs | [Contrat:14–28](</workspace/devloop-019-proof-integrity/docs/tasks/task-019.md#L14-L28>) décrit la garantie et les critères ; [49–64](</workspace/devloop-019-proof-integrity/docs/tasks/task-019.md#L49-L64>) documente la limite des instantanés et le contraste rouge/vert, reproduit ici. [En-tête gate:5–8](</workspace/devloop-019-proof-integrity/scripts/devloop/gate.sh#L5-L8>) et diagnostic `UNVERIFIED` actualisés. |

## Findings (non-blocking)

- **finding — renforcement optionnel de test** : [tests/proof-integrity.sh:57–58](</workspace/devloop-019-proof-integrity/tests/proof-integrity.sh#L57-L58>) exige que `head_after` diffère du SHA initial, mais pas qu'il égale le vrai HEAD final. Ajouter ultérieurement cette égalité améliorerait le test permanent. Ce n'est pas un blocker ici : l'implémentation lit directement HEAD et l'égalité exacte a été vérifiée indépendamment dans les quatre sondes ci-dessus.
- Contexte, pas une régression : `bash scripts/devloop/doctor.sh` avant revue→1, uniquement pour l'absence alors attendue d'une revue approuvante ; avertissement sur le [STATE historique:4–5](</workspace/devloop-019-proof-integrity/docs/STATE.md#L4-L5>). Ni ce STATE ni une future intégration/CI distante ne sont certifiés par cette revue. Les mutations transitoires annulées entre les deux instantanés restent la limite explicitement admise par le contrat.

## Blockers

Aucun.
