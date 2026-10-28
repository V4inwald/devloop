---
task: task-018
sha: e0dc1b21fd777a98c0591d0454206c5382acf24c
verdict: approve
blockers: 0
reviewer: reviewer-018
contract: approved
date: 2026-10-28
---

# Revue — task-018, tour 3

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1/AC6 : `bash tests/run.sh` → `passed: 150, failed: 0`, exit 0 (`/tmp/review018-r3-tests.log`) ; assertions enregistrement `tests/run.sh:907-916` ; assertion « sans push » `tests/run.sh:917-918` (`git ls-remote --heads origin task/050-owner-merge` vide). AC2 : `tests/run.sh:935-944`. AC7 : `tests/run.sh:920-934` (refus « two-parent merge »). AC3 : bloc contrat/taille de la voie fusionnée `integrate.sh:231-242`, exécuté après `BASE="$(git rev-parse "$MERGE_SHA^1")"` (`:230`) et la garde deux parents (`:228-229`). AC4 : 150/0 ; artefact `.git/devloop/gate/e0dc1b21fd777a98c0591d0454206c5382acf24c/result.json` → `"ok": true, "dirty": false`, LINT exit 0, TEST exit 0 ; AC4 du fichier de tâche dit « 148 » pour la r2 et est annoté, non réécrit (`docs/tasks/task-018.md:50-52`). AC5 : ce fichier, verdict `approve`. |
| Tests | Les deux nouveaux tests ne sont pas vacants. « sans push » : seul `main` est poussé avant l'assertion (`tests/run.sh:876,889,926`), la branche n'existe que localement ; un `git push -u origin "$BRANCH"` dans la voie fusionnée rendrait `ls-remote` non vide → l'assertion échouerait. Squash : `SQUASH_SHA` est un `git commit` simple (`tests/run.sh:921-925`, un parent), `headRefOid` = `PR_HEAD` = HEAD donc head/review/ascendance passent et seule la garde peut produire « two-parent merge » ; comme la suite est verte, le refus vient bien de la garde. |
| Test integrity | `git diff --numstat origin/main..HEAD -- tests/run.sh` → `72	0` : zéro ligne supprimée ; `git diff 8c61838..HEAD -- tests/run.sh` → +18/-0. 150 assertions = `README.md:65`. Aucun `skip`/`sleep` ajouté. |
| Correctness | La ré-inline est un pur déplacement : `git diff 8c61838..HEAD -- scripts/devloop/integrate.sh` ne contient que deux hunks (fonction supprimée au chemin normal, bloc équivalent rejoué dans la voie fusionnée), logique identique (mêmes `grep -E`, même `die`, même `diff_lines`). Garde deux parents conservée `:228-229` et placée avant `BASE` (`:230`) et toute écriture. Le prédicat reste `git rev-list --parents -n 1` = 3 mots ; `SQUASH_SHA` à un parent le fait sortir en 2 mots. |
| Errors | L'échec de `gh pr list --state merged` reste un `die` explicite (`integrate.sh:208-210`) ; le refus deux parents et le refus head déplacé ont chacun leur message (`:219-220`, `:229`). |
| Security | JSON de `gh` extrait par `jq -r` (`:212-216`), pas d'`eval` ni de secret ; `MERGE_SHA` validé par ancêtre (`:226-227`) puis deux parents (`:228-229`) avant `BASE` et usage. |
| Compatibility | Miroir identique : `diff -q scripts/devloop/integrate.sh dist/devloop-skill/assets/scripts/devloop/integrate.sh` → identiques ; `bash -n scripts/devloop/integrate.sh` → exit 0 ; clés du record inchangées ; mode local intouché ; chemin normal couvert par les tests existants (`tests/run.sh:817-826`, arrêt sur `REVIEW_REQUIRED`) et inchangé hors ré-inline. |
| Scope | `git diff --numstat origin/main..HEAD` → 462 lignes brutes dont 80 pour `docs/reviews/task-018-r1.md` + `r2.md` ; métrique du projet (`diff_lines` exclut `docs/reviews/`, `common.sh:92-95`) = **382** ≤ `MAX_DIFF_LINES=400`. Fichiers : README, tâche, `integrate.sh` + miroir, `tests/run.sh`, revues r1/r2 (preuves tolérées après leurs SHA revus). |
| Readability | Lisibilité correcte des deux tests. Le bloc contrat+taille est désormais dupliqué (`:154-169` et `:231-242`) : risque de divergence, voir finding 1. |
| Docs | `README.md:65` à 150 ; `docs/tasks/task-018.md` reçoit AC6/AC7 et une note r3 datée qui rétablit la vérité sur le message du commit `8c61838` (annonçait à tort ces tests) et explique l'écart 148→150 ; rien n'est réécrit dans les AC antérieurs. |

## Blockers

None.

## Findings (non-blocking)

1. `scripts/devloop/integrate.sh:154-169` et `:231-242` — le bloc contrat+taille est dupliqué après la ré-inline (gain de budget). Toute correction future doit toucher les deux copies ; `docs/tasks/task-018.md:48-49` parle encore de « factorisation contrat/taille », ce qui ne décrit plus le code. Recommandation : tâche de suivi extrayant à nouveau un helper (ou commentaire croisé « garder les deux blocs identiques ») et mise à jour de la ligne Risks.
2. `tests/run.sh:930-934` — le test squash vérifie le message de refus mais pas l'absence de `$ART_DIR/integrations/$SQUASH_SHA.json`, contrairement au test « head déplacé » (`:943-944`). Le `die` précède toute écriture, donc le comportement est sûr ; l'assertion renforcerait la preuve pour une ligne.
3. Précision de reporting : `git diff --numstat origin/main..HEAD` = **462** (dont 80 lignes de revues), pas 382 ; 382 est la métrique hors `docs/reviews/`, celle de `diff_lines` et de `MAX_DIFF_LINES`. Aucun dépassement, mais c'est la valeur à citer pour que `diff_lines: 382` de l'enregistrement s'explique.
4. `scripts/devloop/integrate.sh:208-209` — `2>/dev/null` masque encore le stderr de `gh` derrière le `die` nommé (reporté de la r2, sans impact).

## Verdict rationale

Les deux demandes du owner sont désormais réellement testées : l'absence de push est prouvée par `ls-remote` sur un remote qui ne contient que `main`, et le squash est refusé par la garde deux parents, seul chemin possible avec un `headRefOid` égal à HEAD. La suite passe à 150/0, le gate du SHA est propre, le miroir est identique et la ré-inline ne change pas la logique (bloc rejoué sur la bonne base, garde conservée). La métrique de taille du projet est à 382/400 ; les deux seules réserves sont la duplication du bloc contrat+taille et une assertion d'absence de record à ajouter, toutes deux non bloquantes et consignées.
