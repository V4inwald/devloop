# 01 — Architecture : une boucle de dev qui produit des preuves

## Le problème réel

Un agent qui code ne produit pas naturellement de la confiance. Il produit des affirmations :
« tests passent », « revue faite », « terminé ». Ces affirmations sont corrélées au travail réel,
mais pas équivalentes. Dès qu'une session est longue, compactée, ou reprise par un autre agent,
la seule chose qui reste fiable est ce qui est **écrit, daté et vérifiable dans le dépôt**.

Le système décrit ici ne cherche donc pas à rendre les agents plus intelligents. Il cherche à
rendre la triche coûteuse, l'état lisible, et la reprise possible sans contexte.

## Quatre principes

1. **La preuve est liée à un commit, pas à une conversation.**
   Un résultat de gate et un verdict de revue nomment le SHA exact qu'ils couvrent. Si le code
   bouge après la revue, la revue ne vaut plus rien. C'est la règle qui empêche « approuvé » de
   devenir un état vague.

2. **Les règles critiques vivent dans la couche dure.**
   Un texte dans `AGENTS.md` ou dans un skill est un conseil : le modèle peut l'ignorer, le
   contourner, ou le perdre à la compaction. Un script qui sort en code 1, un hook git, et une CI
   sont des refus. On met donc dans les scripts tout ce qui doit être obligatoire, et dans les
   textes uniquement ce qui aide à bien faire.

3. **L'état est une machine à états sur disque, avec des transitions refusées.**
   `draft → ready → in_progress → review → done`. Les transitions ne sont pas des conventions :
   `integrate.sh` refuse de fusionner sans gate vert propre et sans revue approuvant HEAD.

4. **La mémoire est stratifiée, versionnée, et sans état caché.**
   Règles stables dans `AGENTS.md`, procédures dans les skills, état et histoire dans `docs/`,
   vérité brute dans git. Une session neuve doit pouvoir tout reconstruire en lisant le dépôt.

## Rôles

| Rôle | Qui | Écrit | Ne fait pas |
|---|---|---|---|
| Lead | agent qui parle à l'humain | fichier de tâche, `STATE.md`, routage | ne code pas la tâche, ne s'auto-approuve pas |
| Implementer | un contexte par tâche | code, tests, notes de tâche | ne rédige pas le verdict |
| Reviewer | **contexte séparé** | uniquement le fichier de revue | ne corrige pas, ne merge pas |
| Integrator | Lead | merge via `integrate.sh` | ne bypasse pas les refus |
| Human | humain | approbations, arbitrages | — |

La séparation Implementer / Reviewer est la seule chose qui distingue une revue d'un tampon.
Un agent seul peut exécuter la boucle, mais sa revue est marquée `reviewer: self` et exige une
approbation humaine avant intégration.

## Flux

```
            ┌──────────────────────────── humain ────────────────────────────┐
            │ objectif, arbitrage, approbation des zones sensibles           │
            └───────────────────────────────┬───────────────────────────────┘
                                            ▼
 task file ──► branche ──► commits ──► gate.sh ──► packet.sh ──► reviewer
 docs/tasks/   task/<id>   atomiques   résultat      diff+gate     (contexte séparé)
                                       lié au SHA                   │
                                            ▲                       ▼
                                            │              docs/reviews/<task>-rN.md
                                            │              (sha:, verdict:, blockers:)
                                            │                       │
                                            └──── gate re-run ──────┘
                                                                    ▼
                                                        integrate.sh (refuse si preuve absente)
                                                                    ▼
                                                     merge commit + audit + STATE.md
```

## Les quatre artefacts

| Artefact | Emplacement | Durée de vie | Rôle |
|---|---|---|---|
| Fichier de tâche | `docs/tasks/<id>.md` | permanent | contrat : critères d'acceptation, périmètre, risque |
| Résultat de gate | `.git/devloop/gate/<sha>/result.json` | local, régénérable | preuve d'exécution des commandes du projet |
| Verdict de revue | `docs/reviews/<task>-rN.md` | versionné, immuable | preuve d'un regard indépendant, lié au SHA |
| Enregistrement d'intégration | `.git/devloop/integrations/<merge-sha>.json` | local | trace de ce qui a été fusionné, avec quel verdict |

Les artefacts locaux ne sont pas commités (volume, bruit). Les verdicts le sont : ils racontent
l'histoire du projet et permettent à la CI de vérifier qu'un merge a bien été revu.

## Pourquoi pas « juste une boucle Ralph »

Une boucle Ralph est un moteur d'itération : elle relance un agent frais jusqu'à ce qu'il déclare
avoir fini. C'est utile pour l'exploration et les longues migrations. Ce n'est pas une preuve :
le critère d'arrêt est un rapport de worker, pas un résultat de test.

La bonne composition est **Ralph à l'intérieur du pipeline** : Ralph sert à itérer sur une tâche,
mais chaque itération est arrêtée par `gate.sh`, et la sortie de la boucle n'est acceptée que si
les artefacts existent. Le pipeline, lui, ne dépend pas de Ralph et fonctionne avec un agent
unique, une équipe, ou un workflow déterministe.

## Ce que ça coûte

- **Étapes** : une tâche passe de « coder » à « tâche + gate + paquet + revue + intégration ».
  Sur une faute de frappe dans un commentaire, c'est disproportionné.
- **Latence** : la revue ajoute un aller-retour de contexte, parfois deux.
- **Tokens** : le paquet de revue duplique le diff ; la revue le relit. Prévoir une hausse
  sensible par tâche, à mesurer plutôt qu'à supposer.
- **Cérémonie** : deux rounds de revue maximum, sinon la boucle devient un rituel.

L'allègement acceptable porte sur la **profondeur de revue** (diff de docs, changement mécanique),
jamais sur le gate : les tests et le lint restent obligatoires pour tout ce qui s'exécute.

## Non-objectifs

- Décider à la place de l'humain sur le produit, la sécurité ou les migrations destructrices.
- Garantir l'absence de bug : un gate vert prouve que les tests configurés passent, rien de plus.
- Remplacer la CI par des scripts locaux : la CI reste l'arbitre qui ne peut pas être contourné
  par `--no-verify`.
