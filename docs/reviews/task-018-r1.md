---
task: task-018
sha: f1498e53e85fa28f4e118e7114def58386c0632a
verdict: revise
blockers: 1
reviewer: reviewer-018
contract: approved
date: 2026-10-28
---

# Revue — task-018, tour 1

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `bash tests/run.sh` → `passed: 148, failed: 0`, exit 0 (log `/tmp/review018-tests.log`) ; section « owner-merged pr » `tests/run.sh:874-917` (enregistrement, `head_sha`, `base` = `merge^1`). Aucun `git push` / `gh pr create` dans la branche fusionnée : `sed -n '211,229p' scripts/devloop/integrate.sh \| grep -E 'push\|pr create\|pr merge'` → aucun résultat ; les seuls push sont `scripts/devloop/integrate.sh:231,273` (voie PR normale) et `:363` (mode local). AC2: `tests/run.sh:920-928` ; refus `branch moved after the merge` (`integrate.sh:218-219`) et aucun enregistrement. AC3: `integrate.sh:228` `BASE="$(git rev-parse "$MERGE_SHA^1")"` puis `:229` `check_contract_and_size` ; fonction unique `integrate.sh:156-169`, donc même code contrat+taille que la voie normale. AC4: 148/0 ; artefact `.git/devloop/gate/f1498e53e85fa28f4e118e7114def58386c0632a/result.json` → `"ok": true, "dirty": false`, LINT exit 0, TEST exit 0. AC5: ce fichier — verdict `revise` (bloqueur ci-dessous). |
| Tests | 6 assertions ajoutées, `tests/run.sh:874-928`. Sans le correctif le test échoue : le faux `gh` ne répond qu'à `auth status`, `repo view`, `pr list` (`tests/run.sh:893-903`) et renvoie le JSON fusionné aussi pour la liste `--state open` ; l'ancienne version (parent de `f1498e5`) prend donc la voie PR normale, puis `gh pr view` sort 1 et `expect_ok` échoue. Non rejoué par mutation : l'ancien chemin attend 24×5 s de checks avant d'échouer ; vérification statique ci-dessus. |
| Test integrity | `git diff --numstat origin/main..HEAD -- tests/run.sh` → `56	0` : zéro ligne supprimée, aucune assertion retirée ; aucun `skip`/`sleep` ajouté dans le test. 148 assertions = `README.md:65`. Les `sleep 5` de `integrate.sh` sont déplacés dans la branche normale (identiques au parent), pas ajoutés. |
| Correctness | Voie fusionnée : head égal à HEAD (`integrate.sh:218-219`), `reviewDecision` APPROVED ou vide (`:220-223`), `merge_sha` ancêtre de `origin/$MAIN_BRANCH` (`:225-227`), `BASE` = `merge^1` (`:228`), contrat+taille rejoués (`:229`). Pré-check non masquant : `check_contract_and_size` est d'abord appelée sur le merge-base écrasé (`:170`) puis rejouée après réassignation de `BASE` (`:229`) ; `diff_lines` lit `$1..HEAD` (`common.sh:92-95`), donc la nouvelle base. **Bloqueur :** aucun contrôle « deux parents » (`grep -n '\^2\|parents' scripts/devloop/integrate.sh` → rien). |
| Errors | Chaque refus de la voie fusionnée a un `die` explicite (`integrate.sh:217,218,222,225,227`) ; le refus testé sort avant toute écriture (écriture uniquement `:302-311`). Finding : `2>/dev/null \|\| true` en `:209-210` avale l'échec de la requête `gh pr list --state merged`. |
| Security | Pas de nouvelle entrée externe exécutée : le JSON de `gh` est extrait par `jq -r` (`integrate.sh:212-216`), sans `eval` ; aucun secret, aucun chemin traversable. Non applicable au-delà. |
| Compatibility | Miroir identique : `diff -q scripts/devloop/integrate.sh dist/devloop-skill/assets/scripts/devloop/integrate.sh` → identiques. Mode local intact (les lignes `integrate.sh:320+` sont du contexte, non modifiées) ; `bash -n scripts/devloop/integrate.sh` → exit 0. Format de l'enregistrement inchangé (mêmes clés qu'une intégration normale). |
| Scope | 5 fichiers, tous dans le Scope de la tâche ; `git diff --numstat origin/main..HEAD` → 276 + 119 = 395 lignes changées (< 400). |
| Readability | Extraction en fonction `check_contract_and_size` lisible, commentaires expliquant la nouvelle branche. Aucun problème bloquant. |
| Docs | `README.md:65` à jour (148) ; `docs/tasks/task-018.md` ajouté. Finding contractuel : `docs/tasks/task-018.md:44-45` annonce « un merge à deux parents » comme mitigation, mais le code ne le vérifie pas — c'est le bloqueur. |

## Blockers

1. `scripts/devloop/integrate.sh:211-229` — la branche « PR déjà fusionnée » n'exige pas un commit de fusion à deux parents, alors que `docs/tasks/task-018.md:44-45` l'annonce comme mitigation du risque de détection trop large. Un squash merge (tout `mergeCommit.oid` à un seul parent) est donc accepté et enregistré comme une intégration : `head_sha` (head de PR) n'est pas un ancêtre de `merge_sha`, et `base = merge^1` n'est plus le premier parent d'une fusion du head revu. `doctor.sh:131-135` certifie ensuite `main` comme « integration merge (head …) » sur cette base. Correctif minimal : après le contrôle d'ancêtre (`integrate.sh:226-227`), ajouter `git rev-parse --verify --quiet "$MERGE_SHA^2" >/dev/null || die "commit $MERGE_SHA is not a two-parent merge; refusing to record it"` ; le test utilise déjà `git merge --no-ff`, donc reste vert.

## Findings (non-blocking)

- `scripts/devloop/integrate.sh:209-210` — `2>/dev/null || true` avale l'échec de `gh pr list --state merged` ; le script retombe alors silencieusement sur la voie « ouvrir une PR » (push du head et PR en double pour une PR déjà fusionnée) et, sur un `gh` refusant ces flags, la fonctionnalité reste inerte sans message. `gh pr list` sort 0 avec `[]` quand il n'y a aucune PR : `|| die "cannot query merged pull requests"` est plus sûr.
- `tests/run.sh:905-917` — le test ne prouve pas « sans pousser » : le faux `gh` n'intercepte que `gh` ; un `git push -u origin` accidentel passerait. Ajouter une assertion `git ls-remote --exit-code origin refs/heads/task/050-owner-merge` (absent) après l'exécution.
- `tests/run.sh:927-928` — « no record is written for a refused merge » teste `$ART/integrations/$FAKE_MERGE.json` avec un SHA fabriqué qui ne pourrait jamais être écrit ; assertion quasi vide. Comparer le contenu de `$ART/integrations/` avant/après le refus.

## Verdict rationale

Le cœur de la tâche est correct et réellement testé : chemin fusionné sans push ni création de PR, refus quand le head de la PR diffère de HEAD, contrat et taille rejoués sur `<merge>^1` avec le code partagé, 148 assertions au vert et miroir identique. Le bloqueur est l'écart entre la mitigation annoncée dans la tâche et le code : sans contrôle `^2`, l'enregistrement peut certifier comme intégration une fusion qui n'a pas fusionné le head revu, ce qui affaiblit le modèle de preuve que cette tâche doit renforcer. Deux lignes de garde suffisent ; sans autre changement, le tour 2 peut approuver.
