---
task: task-018
sha: 0b379e1f366c448a4e42ef34b56f8582913f6b26
verdict: approve
blockers: 0
reviewer: reviewer-019
contract: approved
date: 2026-10-28
---

# Revue task-018 — ronde 4 (owner, PR #20)

Revue indépendante : je n'ai pas écrit ce changement et je ne l'ai pas modifié.
État vérifié : branche `task/018-record-owner-merge`, HEAD = `0b379e1f366c448a4e42ef34b56f8582913f6b26`,
arbre propre avant rédaction (`git status --porcelain` vide).

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC12 (une seule fonction) : `scripts/devloop/integrate.sh:156-169` définit `check_contract_and_size`, appelée en `:170` (voie normale) et `:232` (voie fusionnée) ; `grep -n "check_contract_and_size" scripts/devloop/integrate.sh` ne renvoie qu'une définition et deux appels, aucun bloc de contrôle dupliqué. AC8 (base = point de fork) : `:231` `BASE="$(git merge-base "$SHA" "$MERGE_SHA^1")"`, record `:309`/`:313` `--arg base "$BASE"` ; test `tests/run.sh:885-894` avance `main` d'un commit touchant `AGENTS.md` (chemin de contrat) après le fork, `:893` `EXPECTED_BASE=merge-base(PR_HEAD, MERGE_050^1)`, `:920-925` assert base = point de fork ET base != `MERGE^{1}`. AC9 (contrat refusé en fusionné, aucun record) : `tests/run.sh:950-974`. AC10 (taille refusée en fusionné, aucun record) : `:976-999` (401 lignes > `MAX_DIFF_LINES=400`, `.devloop.conf:7`). AC11 (squash sans record + doctor) : `:947-948` et `:928-929` `doctor.sh` sort 0 après enregistrement. AC1/AC2/AC6 : `:912-927`, `:1001-1011`. AC4 : `bash tests/run.sh` -> `passed: 157, failed: 0`. |
| Tests | Les cinq tests r4 existent et sont non vides ; run complet = 157 assertions, 0 échec. Non-vacuité prouvée par mutation dans deux worktrees scratch (`git worktree add --detach /tmp/r4v1 HEAD`, supprimés après) : (a) V1, `BASE` remis à `$MERGE_SHA^1` en `:231` -> `passed: 152, failed: 5` dont `FAIL integrate records an owner-merged PR`, `FAIL integration record written for the merge commit`, `FAIL record base is the fork point, not main's tip`, `FAIL doctor certifies the owner-merged integration` (le faux refus revient) ; (b) V2, suppression de l'appel fusionné `:232` -> `passed: 153, failed: 4` = exactement `FAIL merged mode refuses a contract path without approval`, `FAIL no record for a contract-refused merge`, `FAIL merged mode refuses an oversized diff`, `FAIL/no record for an oversized merge`. Les tests 2 et 3 échouent donc bien sans le correctif. |
| Test integrity | `git diff --numstat origin/main..HEAD -- tests/` -> `139 0 tests/run.sh` : aucune suppression par rapport à `origin/main`. Le diff r4 (`git diff b1d9a01..HEAD -- tests/run.sh`) remplace une assertion (`base = merge^1`) par deux assertions plus strictes (égalité au point de fork + inégalité au parent de merge) ; aucun test sauté, aucun `sleep` ajouté, aucun timeout élevé. |
| Correctness | Le bug owner est corrigé : `git diff <merge>^1..SHA` incluait à l'envers les commits de `main` postérieurs au fork, d'où le faux refus de contrat ; `BASE = merge-base(SHA, <merge>^1)` (`:231`) borne le diff au fork, donc `diff_lines` (`scripts/devloop/common.sh:92-95`) n'additionne plus les lignes de `main`. Le record porte `base:$BASE` (`:309`) et `diff_lines:$lines` (`:313`) calculés après recalcul. La voie normale garde `BASE="$(merge_base)"` (`:85`, `common.sh:65-73`), inchangée. |
| Errors | Chaque refus est explicite et intervient avant l'écriture du record (`:314`) : contrat `:163`, taille `:167`, head déplacé `:219-220`, décision de revue `:221-224`, merge non ancré `:227-228`, merge à un parent `:229-230`. Les tests négatifs vérifient l'absence de fichier `$ART/integrations/<merge>.json` (`tests/run.sh:947, 973, 998, 1010`). |
| Security | L'entrée externe reste le JSON de `gh`, extrait par `jq -r` (`integrate.sh:213-217`) sans `eval` ; `$MERGE_SHA` est validé (ancêtre de `origin/main`, deux parents) avant usage en `git merge-base` puis dans les chemins/records. Scan du packet pour motifs de secret (`api_key|secret|password|token|private key|ghp_`) : seules occurrences du mot « secret » dans la prose des rubriques de revue ; aucun secret, aucune donnée personnelle. |
| Compatibility | Le champ `base` du record change de sens (`<merge>^1` -> point de fork) : c'est la demande owner r4 ; le consommateur `doctor.sh` est couvert (`tests/run.sh:929`), la note datée `docs/tasks/task-018.md:59-61` documente la décision, et le compte d'assertions `README.md:65` passe de 150 à 157, conforme au run. |
| Scope | `git diff --numstat origin/main..HEAD` : `README.md`, `dist/devloop-skill/assets/scripts/devloop/integrate.sh`, `docs/tasks/task-018.md`, `scripts/devloop/integrate.sh`, `tests/run.sh` (+ `docs/reviews/` r1-r3). Aucun fichier hors scope, aucune dépendance ajoutée. Miroir : `diff -q scripts/devloop/integrate.sh dist/devloop-skill/assets/scripts/devloop/integrate.sh` -> exit 0. |
| Readability | Une fonction nommée, commentée (`:154`), paramétrée par `BASE` global documenté en tête de fichier (`:13`), au lieu de deux blocs ; la voie fusionnée ne fait que recalculer `BASE` puis rappeler la même fonction. |
| Docs | `docs/tasks/task-018.md:59-61` : note datée 2026-10-28 (r4) consignant la demande owner (`BASE = merge-base(SHA, <merge>^1)`), la factorisation et l'autorisation explicite du dépassement avec `--allow-oversized` ; `README.md:65` mis à jour (157 assertions). Gate : `$ART/gate/0b379e1.../result.json` -> `ok:true`, `dirty:false`, `sha` = SHA revu, checks LINT exit 0 et TEST exit 0. |

## Oversize (autorisé, non bloquant)

Métrique projet mesurée sur le SHA revu, `docs/reviews/` exclu :
`git diff --numstat "$(git merge-base HEAD origin/main)..HEAD" | awk '$3 !~ /^docs\/reviews\// {a+=$1; d+=$2} END {print a+d}'`
-> `498` > `MAX_DIFF_LINES=400` (`.devloop.conf:7`), réparti en README 2 + miroir 148 + script 148 + task 61 + tests 139.
Le owner a explicitement autorisé ce dépassement pour le tour 4 et demandé `--allow-oversized` : la note datée existe
(`docs/tasks/task-018.md:59-61`). Conformément à la demande, l'oversize n'est pas un blocker.

## Findings (non bloquants)

1. `docs/tasks/task-018.md:21` — AC1 énonce encore `base` = `<merge>^1`, alors que l'AC8 (`:31-32`), l'implémentation
   (`integrate.sh:231`) et la note r4 (`:59-61`) imposent le point de fork. Le contrat est bien documenté par la note
   datée (l'AC ne se réécrit pas après coup), mais un lecteur de l'AC1 seul serait trompé. Suggestion : renvoyer AC1 à la
   note r4 plutôt que réécrire l'AC.
2. `docs/tasks/task-018.md:60` — la note annonce « 489 lignes » pour le diff projet ; la mesure au SHA revu donne 498.
   L'autorisation et le choix de `--allow-oversized` ne sont pas affectés.
3. `scripts/devloop/common.sh:93` — `diff_lines` diffe `$1..HEAD` (HEAD) et non `$1..$SHA` ; sans impact ici car la voie
   fusionnée impose `headRefOid == HEAD` (`integrate.sh:219-220`) et la voie normale suppose `SHA == HEAD`.

## Blockers

Aucun.

`contract: approved` : `scripts/devloop` est touché, mais aucune barrière n'est abaissée — le contrôle de contrat refuse
toujours sans `contract: approved` (test `tests/run.sh:950-974`, et V2 montre que le retrait de l'appel fusionné casse ce
test), le contrôle de taille reste appliqué par la même fonction, et le changement de base borne le diff au fork comme
l'owner l'a exigé au lieu de differ `main` à l'envers.
