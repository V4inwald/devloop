---
task: task-018
sha: 8c618384959b0a0e57fad2ba182c50fcf2130635
verdict: approve
blockers: 0
reviewer: reviewer-018
contract: approved
date: 2026-10-28
---

# Revue — task-018, tour 2

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1 : `bash tests/run.sh` → `passed: 148, failed: 0`, exit 0 (`/tmp/review018-r2-tests.log`) ; assertions d'enregistrement `tests/run.sh:911-916` (fichier, head de PR, base = `merge^1`) ; aucun push ni création de PR dans la branche fusionnée : `sed -n '212,231p' scripts/devloop/integrate.sh \| grep -E 'git push\|pr create'` → aucun résultat. AC2 : `tests/run.sh:917-926`, refus `branch moved after the merge` (`integrate.sh:219-220`) et aucun enregistrement. AC3 : `integrate.sh:231` `BASE="$(git rev-parse "$MERGE_SHA^1")"` puis `:232` `check_contract_and_size` ; fonction unique `integrate.sh:156-169`, même code que la voie normale. AC4 : 148/0 ; artefact `.git/devloop/gate/8c618384959b0a0e57fad2ba182c50fcf2130635/result.json` → `"ok": true, "dirty": false`, LINT exit 0, TEST exit 0. AC5 : ce fichier, verdict `approve`. |
| Tests | 6 assertions dans la section « owner-merged pr » (`tests/run.sh:874-926`), toutes exécutées (148/0). La nouvelle garde deux parents n'a pas de test dédié : voir finding 1 (budget `MAX_DIFF_LINES`), comportement vérifié par inspection + prédicat ci-dessous. |
| Test integrity | `git diff f1498e5..HEAD -- tests/run.sh` → suppression d'une ligne vide et d'un commentaire uniquement ; aucun `ok`/`ko`/`expect_*` supprimé, `git diff --numstat origin/main..HEAD -- tests/run.sh` → `54	0`. 148 assertions = `README.md:65`. |
| Correctness | Garde ajoutée `integrate.sh:229-230` : `git rev-list --parents -n 1 "$MERGE_SHA" \| wc -w` = 3 exigé, sinon `die`. Prédicat vérifié : merge `4f0ebbd` → 3 mots ; commit simple `f1498e5` → 2 mots. Elle est placée après l'ascendance (`:227-228`) et **avant** `BASE=` (`:231`) et l'écriture du record, donc un squash merge (un parent) est refusé avant tout calcul et toute écriture. `git diff f1498e5..HEAD -- scripts/devloop/integrate.sh` ne contient que deux hunks (garde + `\|\| die`), aucun autre changement. |
| Errors | `MERGED_JSON=…` échoue désormais explicitement : `integrate.sh:209-211` `\|\| die "cannot query merged pull requests; check gh auth and network"` (plus de `\|\| true`). Finding 2 : `2>/dev/null` supprime encore le stderr de `gh` ; le message nomme la cause probable mais pas l'erreur exacte. |
| Security | JSON de `gh` extrait par `jq -r` (`integrate.sh:213-217`), pas d'`eval`, pas de secret ; entrée `MERGE_SHA` validée par ancêtre + deux parents avant usage. |
| Compatibility | Miroir identique : `diff -q scripts/devloop/integrate.sh dist/devloop-skill/assets/scripts/devloop/integrate.sh` → identiques ; `bash -n scripts/devloop/integrate.sh` → exit 0 ; voie PR normale non modifiée depuis le tour 1 hors le `\|\| die` (`:209-211`) ; mode local intouché ; clés du record inchangées. |
| Scope | `git diff --numstat origin/main..HEAD` → 439 lignes brutes dont 40 pour `docs/reviews/task-018-r1.md`, soit 399 hors revue ; `diff_lines` exclut justement `docs/reviews/` (`common.sh:92-95`), donc la métrique de taille du projet = 399 ≤ 400. Fichiers : README, tâche, `integrate.sh` + miroir, `tests/run.sh`, revue r1 (preuve, tolérée après le SHA revu). |
| Readability | Garde d'une ligne lisible et `die` explicite ; le commentaire décrivant le scénario de refus a été retiré de `tests/run.sh` pour tenir dans le budget (finding 3, sans impact). |
| Docs | `README.md:65` à jour (148) ; `docs/tasks/task-018.md:44-45` annonce désormais une mitigation réellement implémentée (`integrate.sh:229-230`) ; findings du tour 2 consignés ici. |

## Blockers

None.

## Findings (non-blocking)

1. `scripts/devloop/integrate.sh:229-230` — la garde deux parents n'a pas d'assertion dans `tests/run.sh` : le budget de taille est saturé (399/400, et les 40 lignes de la revue r1 sont exclues par `diff_lines`). Recommandation : petite tâche de suivi ajoutant un cas « squash merge refusé » (faux `gh` avec `mergeCommit` = commit à un parent). Comportement vérifié ici par inspection et par le prédicat (`merge` → 3 mots, commit simple → 2).
2. `scripts/devloop/integrate.sh:209-210` — `2>/dev/null` masque toujours le stderr de `gh` ; le `die` nomme la classe de cause mais pas l'erreur exacte. `gh pr list` sort 0 avec `[]` quand il n'y a aucune PR, donc la suppression du stderr n'est pas nécessaire.
3. `tests/run.sh:917` — le commentaire « A branch that moved after the merge must be refused » a été supprimé avec la ligne vide pour gagner 2 lignes ; l'assertion reste. À restaurer quand la marge de taille le permettra.

## Verdict rationale

Les deux corrections demandées sont présentes, correctement placées et vérifiables : la garde à trois mots refuse tout `mergeCommit` non fusionnel avant `BASE`/record, et l'échec de la requête des PR fusionnées n'est plus avalé. Les contrôles indépendants passent (148/0, gate `ok=true dirty=false`, miroir identique, `bash -n` 0, 399 lignes mesurées par le projet). Aucun bloqueur : le seul manque est le test dédié de la garde, impossible à caser sous `MAX_DIFF_LINES` dans ce tour et sans effet sur la sûreté du correctif ; il est consigné pour un suivi.
