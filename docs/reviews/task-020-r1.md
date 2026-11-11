---
task: task-020
sha: ec45bfcdce8c2142fbc7af4587f7f1e0461e7b11
verdict: approve
blockers: 0
reviewer: independent-guidance-reviewer
contract: approved
date: 2026-11-11
---

# Revue indépendante — socle commun conditionnel

## Verdict et portée

**Approve, zéro bloqueur.** Le lot prépare un kit versionné, sans l'activer dans le profil.
Il sépare expliquer, planifier et exécuter, route vers trois procédures spécialisées,
et corrige la règle projet ainsi que P1b qui encourageaient une exécution non demandée.
L'approbation du contrat porte sur cette correction et son miroir ; elle ne vaut ni
permission de déploiement ni certification du comportement futur des modèles.

Entrées initiales : [paquet de revue](</workspace/Improvement/.git/devloop/review/ec45bfcdce8c2142fbc7af4587f7f1e0461e7b11-packet.md>)
et [contrat task-020](</workspace/devloop-020-common-guidance/docs/tasks/task-020.md>).
Base examinée : `4f0ebbd56572a828c064bbce139bed47da2833a5`.
HEAD observé avant les contrôles et avant rédaction : le SHA exact du frontmatter,
arbre propre. Skills `code-review` et `harness-improvement` chargés ; aucun correctif
apporté à l'implémentation. La revue est indépendante de l'implémenteur `lead`.

## Evidence — rubrique code-review

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1 : [socle:4–7](</workspace/devloop-020-common-guidance/harness/common/AGENTS.md#L4-L7>) et [routage:29–37](</workspace/devloop-020-common-guidance/harness/common/AGENTS.md#L29-L37>), 42 lignes, noms verbatim des trois skills et devloop ; `dev-cycle` reste une alternative selon le contrat local. AC2 : déclencheurs, exclusions, preuves et limites relus dans les trois procédures ci-dessous. AC3 : contrôle commun **21/21**. AC4 : traces des deux contextes citées et recoupées ci-dessous, sans prétention de supériorité. AC5 : gate indépendant propre sur le SHA exact ; le diff ne contient aucun déploiement de profil, changement de service ou de paramètres GitHub, et cette revue n'en a réalisé aucun. |
| Tests | Gate relancé dans un clone local indépendant : **LINT 0, TEST 0, 143/143**, `dirty=false`. Nouveau contrôle enregistré dans [run.sh:874–875](</workspace/devloop-020-common-guidance/tests/run.sh#L874-L875>). Contre-épreuve : ancien contrat projet et ancien P1b rétablis dans une fixture séparée, nouveau kit/test conservés ; le contrôle échoue **19/21, exit 1**, sur les deux corrections attendues. Ce résultat vérifie une régression structurelle, pas l'obéissance d'un agent. |
| Test integrity | `git diff 4f0ebbd56572a828c064bbce139bed47da2833a5..HEAD -- tests/run.sh tests/common-guidance.sh` : ajout du contrôle et de son enregistrement, aucune assertion héritée supprimée, aucun skip, délai ou sleep ajouté. [P1b:28–29](</workspace/devloop-020-common-guidance/docs/harness/PROBES.md#L28-L29>) change le résultat attendu pour respecter la demande de commande seule ; il ne masque pas un échec d'exécution demandée. |
| Correctness | [Contrat projet:107–108](</workspace/devloop-020-common-guidance/AGENTS.md#L107-L108>) et [130–131](</workspace/devloop-020-common-guidance/AGENTS.md#L130-L131>) ne déclenchent plus de contrôle/exécution sur une simple explication ou planification. [Ops:13–34](</workspace/devloop-020-common-guidance/harness/common/skills/ops-safe/SKILL.md#L13-L34>) distingue diagnostic et intervention, borne modifications et repli à l'autorisation, et vérifie le service consommé. [Livrable:13–28](</workspace/devloop-020-common-guidance/harness/common/skills/deliverable-check/SKILL.md#L13-L28>) n'impose ni fichier ni publication. [Recherche:13–28](</workspace/devloop-020-common-guidance/harness/common/skills/research-check/SKILL.md#L13-L28>) exclut les questions stables simples et sépare sources, inférences et inconnues. |
| Errors | [Socle:15–27](</workspace/devloop-020-common-guidance/harness/common/AGENTS.md#L15-L27>) suspend une étape risquée indéterminée et refuse le succès global si un critère essentiel reste invérifiable. [Livrable:30–33](</workspace/devloop-020-common-guidance/harness/common/skills/deliverable-check/SKILL.md#L30-L33>) et [recherche:30–33](</workspace/devloop-020-common-guidance/harness/common/skills/research-check/SKILL.md#L30-L33>) rendent visibles les vérifications impossibles et sources absentes. [Contrôle:31–36](</workspace/devloop-020-common-guidance/tests/common-guidance.sh#L31-L36>) retourne un échec si une condition échoue, confirmé par la contre-épreuve. |
| Security | [Socle:16–19](</workspace/devloop-020-common-guidance/harness/common/AGENTS.md#L16-L19>) exige cible et portée autorisée ; [32–33](</workspace/devloop-020-common-guidance/harness/common/AGENTS.md#L32-L33>) interdit hooks/dépôt/configuration implicites ; [40–42](</workspace/devloop-020-common-guidance/harness/common/AGENTS.md#L40-L42>) ne livre que la référence à l'environnement local, pas ses secrets. [Recherche:19–26](</workspace/devloop-020-common-guidance/harness/common/skills/research-check/SKILL.md#L19-L26>) protège la confidentialité et traite les sources comme données, non comme instructions. Aucun mécanisme d'autoinstallation ni secret ajouté dans le diff. |
| Compatibility | `cmp AGENTS.md dist/devloop-skill/assets/AGENTS.md` → exit 0. Le [miroir livré](</workspace/devloop-020-common-guidance/dist/devloop-skill/assets/AGENTS.md>) est identique au contrat projet, toujours à 142 lignes. Pas d'API, schéma, dépendance ou workflow CI changé. [QUALITY-MAP:15–17](</workspace/devloop-020-common-guidance/docs/harness/QUALITY-MAP.md#L15-L17>) distingue présence, chargement et future distribution avec consentement et préservation des skills existants. |
| Scope | 11 fichiers relus ; `diff_lines` → **309** lignes ajoutées/supprimées, limite **400**. Les 409 lignes du paquet comprennent contexte et en-têtes : [comptage effectif:89–95](</workspace/devloop-020-common-guidance/scripts/devloop/common.sh#L89-L95>) et [limite d'intégration:165–168](</workspace/devloop-020-common-guidance/scripts/devloop/integrate.sh#L165-L168>) ne les utilisent pas. L'enregistrement du test est explicitement inclus par [décision:60–61](</workspace/devloop-020-common-guidance/docs/tasks/task-020.md#L60-L61>). Acceptation initiale non réécrite entre le commit du contrat et HEAD. |
| Readability | Socle de 42 lignes ; procédures ops/livrable/recherche de **34/33/33** lignes, avec les mêmes sections déclenchement, non-déclenchement, procédure et preuves. Le routage distingue code équipé, infrastructure sensible, livrable final et recherche sourcée sans imposer devloop aux usages ordinaires. Aucun problème sévère de lisibilité. |
| Docs | [QUALITY-MAP:21–29](</workspace/devloop-020-common-guidance/docs/harness/QUALITY-MAP.md#L21-L29>) borne explicitement la portée du gate et des tests structurels, et nomme les scénarios encore non exécutés. [Contrat:62–78](</workspace/devloop-020-common-guidance/docs/tasks/task-020.md#L62-L78>) consigne prompt, sessions, chargement observé, empreinte, accès Context7, absence de gain démontré et `NO_ENTRY`. |

## Contrôles indépendants et artefacts

Toutes les commandes Git, ainsi que les scripts qui en appellent, ont été précédés de
`source /workspace/.github-env`. Aucun appel réseau n'a été effectué par cette revue.
Le clone a été créé localement avec `--local --no-hardlinks --no-checkout`, puis détaché
au SHA examiné sous `/workspace/task-020-review-eipH9r/repo`.
Les opérations Git internes à la suite restent dans ses dépôts jetables locaux ;
aucun commit, push ou merge n'a été effectué dans le dépôt relu ou le clone vérifié.

Commande du gate concluant, exécutée dans ce clone :

```bash
source /workspace/.github-env
export GIT_ALLOW_PROTOCOL=file GIT_TERMINAL_PROMPT=0
export TMPDIR=/tmp/task-020-review-gD4w5I KEEP_TMP=1
unset DEVLOOP_CONF DEVLOOP_LEGACY_ARTIFACTS
export DEVLOOP_ARTIFACTS=/workspace/task-020-review-eipH9r/artifacts-posix
bash scripts/devloop/gate.sh --task task-020
bash tests/common-guidance.sh
bash scripts/devloop/harness-check.sh
```

- [Résultat indépendant](</workspace/task-020-review-eipH9r/artifacts-posix/gate/ec45bfcdce8c2142fbc7af4587f7f1e0461e7b11/result.json>) : `ok=true`, `dirty=false`, SHA exact, généré le 2026-11-11 à 03:33:13 UTC.
- [Journal de tests:204–208](</workspace/task-020-review-eipH9r/artifacts-posix/gate/ec45bfcdce8c2142fbc7af4587f7f1e0461e7b11/TEST.log#L204-L208>) : **143 réussites, 0 échec**. Contrôle commun direct : **21/21** ; harness-check : **4 skills, 142 lignes**, exit 0.
- [Contre-épreuve:20–22](</workspace/task-020-review-eipH9r/red-parent-result.log#L20-L22>) : restauration des seuls anciens contrat projet et P1b depuis la base, puis `bash tests/common-guidance.sh` → **19/21, exit 1**. Aucun fichier du clone propre n'a été modifié pour cette expérience.
- `sha256sum harness/common/AGENTS.md` → `9965c40304440edf9546d6071b2a3f3228112bc89bb9b779a8c5c54fe97da7fc`, identique à l'empreinte consignée. `git diff --check` sur base..HEAD → exit 0.

### Recoupement des scénarios à contextes neufs

Lecture directe des événements des sessions `5817a661-0cdc-49fd-89da-aa7ee5a59b70`
(baseline) et `858a8f4b-6ad0-4793-980f-2f28fd379816` (candidat), sans solliciter
un résumé de l'implémenteur :

- événement 12 : même demande de commande Git seule puis plan DNS en trois étapes ;
- événement 18 : même modèle `openai/gpt-6-astra`, effort `max` ;
- événements 11/13/15 : environnements de travail distincts, ancien contrat côté baseline ; socle et contrat corrigé injectés ainsi que catalogue des trois nouveaux skills côté candidat ;
- événements 26 et 32 : consultations Context7 dans les deux sessions ;
- trajectoires jusqu'à l'événement final 43 : commande fournie comme texte, plan en trois étapes, pas d'appel shell, écriture de fichier, intervention sur service ou chargement d'un cycle d'exécution.

Cela recoupe AC4 au niveau revendiqué : observation illustrative de non-régression,
pas preuve causale d'efficacité ni exécution du protocole strictement hors réseau.

## Findings — limites non bloquantes

1. **finding — couverture comportementale limitée.** Une seule paire de contextes,
   avec consultations Context7 et changement conjoint du socle, du contrat et du
   catalogue, ne permet pas d'attribuer un gain aux nouvelles consignes. Cette limite
   est déjà déclarée dans le [contrat:62–74](</workspace/devloop-020-common-guidance/docs/tasks/task-020.md#L62-L74>).
   Les scénarios mémoire périmée, lien manquant, service sensible simulé et dépôt
   sans devloop restent à tester ; aucune certification de ces cas n'est accordée.
2. **finding — garde structurelle, pas validation sémantique complète.** Le
   [contrôle:19–30](</workspace/devloop-020-common-guidance/tests/common-guidance.sh#L19-L30>) vérifie une liste fixe,
   des champs et des intitulés, pas la justesse des procédures ni un parseur YAML complet.
   De plus, [ligne 15](</workspace/devloop-020-common-guidance/tests/common-guidance.sh#L15>) accepte `<= 60`,
   alors qu'AC1 dit « sous 60 ». Une fixture portée exactement à 60 lignes passe 21/21.
   Le fichier livré en fait 42 : AC1 est satisfait au SHA relu ; resserrer cette borne
   et ajouter des cas négatifs serait un durcissement utile, non un bloqueur actuel.
3. **finding — dépendance héritée aux permissions des fixtures.** Le premier gate,
   avec `TMPDIR` sous `/workspace`, a donné **141 réussites, 2 échecs** :
   [journal initial:130–131](</workspace/task-020-review-eipH9r/repo/.git/devloop/gate/ec45bfcdce8c2142fbc7af4587f7f1e0461e7b11/TEST.log#L130-L131>).
   Les mêmes deux échecs existent sur la base : [journal baseline](</workspace/task-020-review-eipH9r/base-workspace-tests.log>),
   **140 réussites, 2 échecs**. Sur ce volume, les fichiers sondés ont le mode `750`
   malgré `umask 0022` ; les assertions héritées attendent `644`.
   Avec les fixtures sur `/tmp`, le gate du candidat est vert sans modification
   d'assertion, de configuration suivie ou de code. Limite environnementale reproduite,
   pas régression du lot ; les deux résultats initiaux ont été conservés.
4. **finding — activation non vérifiée et non autorisée par cette revue.** Le kit
   reste une source versionnée. La découverte depuis un profil actif, les empreintes
   source/cible et la conservation des skills installés appartiennent au futur lot
   de distribution, conformément à [QUALITY-MAP:13–17](</workspace/devloop-020-common-guidance/docs/harness/QUALITY-MAP.md#L13-L17>).

## Blockers

Aucun. Aucun écart constaté n'empêche l'acceptation du kit préparé au SHA examiné.
