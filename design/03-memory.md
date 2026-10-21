# 03 — Mémoire : quatre couches, aucune boîte noire

La question « comment je mets ça dans une mémoire ? » a une réponse précise : on ne met pas le
système dans un fichier unique. On répartit selon la fréquence de lecture, la stabilité, et le
coût de chargement.

## Les quatre couches

| Couche | Fichier / mécanisme | Chargée | Contenu | Fréquence d'écriture |
|---|---|---|---|---|
| 1. Chaude | `AGENTS.md` racine | **chaque requête**, automatiquement | règles non négociables, carte mémoire, commandes | rarement, revue comme du code |
| 2. Procédurale | `.agents/skills/<nom>/SKILL.md` | sur demande, via `skill` | étapes, rubriques, formats | quand le process change |
| 3. État / histoire | `docs/STATE.md`, `docs/tasks/`, `docs/adr/`, `docs/reviews/`, `docs/LESSONS.md`, commits, PR | jamais automatiquement ; lue sur instruction | vérité datée, décisions, preuves | à chaque tâche |
| 4. Rappel inter-sessions | outils mémoire DSH (scope projet) | injectée dans le contexte | pointeurs courts, décisions durables | 1 à 2 entrées par jalon |

Le point important : **seule la couche 1 est garantie présente**. Tout le reste doit être
retrouvable parce qu'un fichier le dit, pas parce qu'un agent s'en souvient.

## Couche 1 — `AGENTS.md`

Rôle : dire au nouvel agent *où* regarder et *ce qui est interdit*. Pas de détails de tâche, pas
d'historique, pas de code.

Règles de rédaction :

- Budget humain : ~150–200 lignes. Le budget technique de DSH est de 65 536 octets, mais un
  fichier long dilue les règles importantes.
- Chaque ligne doit être **stable** et **normative**. Si elle change à chaque tâche, elle va
  dans `STATE.md` ou dans une tâche.
- Toute règle critique a un renvoi vers le script qui l'applique. Un texte sans mécanisme est une
  intention, pas une règle.
- Un changement d'`AGENTS.md` est un changement de contrat : il passe par une tâche et une revue
  comme le reste.

## Couche 2 — skills

Un skill est une procédure : il décrit *comment* faire, avec des commandes exactes, des formats
de sortie, et des conditions d'arrêt. Il n'a pas à répéter les règles de fond.

- Déclenchement : `description` et `whenToUse` doivent contenir les mots que l'utilisateur ou
  l'agent emploiera (« revue », « tâche », « refactor »).
- Un skill par procédure. Si un skill dépasse ~150 lignes, c'est souvent qu'il mélange deux
  responsabilités.
- Un skill se modifie en même temps que les scripts qu'il décrit, sinon il ment.

## Couche 3 — état et histoire

C'est la couche qui survit aux sessions, aux modèles, et aux machines.

| Fichier | Règle | Pourquoi |
|---|---|---|
| `STATE.md` | toujours estampillé `last_verified_sha` | détecte l'état périmé |
| `docs/tasks/<id>.md` | contrat initial immuable ; notes ajoutées datées | empêche de réécrire l'objectif après coup |
| `docs/adr/NNNN-*.md` | immuable une fois accepté ; remplacé par un nouvel ADR | décisions stables et traçables |
| `docs/reviews/*.md` | immuable après commit | la preuve ne se réécrit pas |
| `docs/LESSONS.md` | ajout seul, une ligne datée | transmet un réflexe, pas une histoire |
| git | jamais réécrit sur les branches partagées | vérité brute |

**Règle d'estampille** : tout document d'état commence par le SHA qu'il décrit. `doctor.sh`
compare `STATE.md` à HEAD. Un écart n'est pas une erreur fatale : c'est un signal « ne fais pas
confiance à cet état sans re-vérifier ».

**Règle d'immutabilité** : on ne corrige pas une revue passée ni un ADR accepté. On ajoute. Cela
évite la réécriture de l'histoire pour justifier une décision présente.

## Couche 4 — mémoire inter-sessions

Les outils mémoire de DSH (`memory_remember`, `memory_search`) servent à **retrouver le dépôt**,
pas à le remplacer. Une entrée utile tient en une phrase et pointe vers une source.

Bon : « Le kit devloop de ce projet impose des preuves liées au SHA ; voir `AGENTS.md` et
`design/04-gates-and-review.md`. »

Mauvais : recopier les règles, les chemins de fichiers, ou un résumé de conversation. Si le
dépôt change, la mémoire devient fausse sans que personne ne le voie.

Règles :

- scope `project` pour tout ce qui est propre à ce dépôt ;
- 3 à 5 entrées maximum à la création, puis une par décision structurante ;
- jamais de secret, de token, de donnée personnelle ;
- une entrée = un fait durable, pas une humeur ni un état d'avancement (l'avancement est dans
  `STATE.md`).

## Démarrage de session

`AGENTS.md` §8 l'impose, et c'est volontairement court :

1. lire `docs/STATE.md` ;
2. lancer `bash scripts/devloop/doctor.sh` ;
3. lire le fichier de la tâche en cours ;
4. si `last_verified_sha` != HEAD, re-vérifier avant d'agir.

Coût : quatre lectures. Bénéfice : un agent qui reprend un projet de trois mois sans demander
« où on en est ? ».

## Ce qui ne va **pas** dans la mémoire

- les logs de gate (volumineux, régénérables) : ils restent dans `.devloop/artifacts/` ;
- le code dupliqué dans un document : il dérive immédiatement ;
- les résumés de conversation : ils ne sont pas vérifiables ;
- les secrets et identifiants : jamais, dans aucune couche ;
- les états d'avancement optimistes : `STATE.md` ne contient que ce que les artefacts prouvent.

## Anti-dérive : trois mécanismes

1. **Estampille SHA** — un document qui décrit un état qui n'existe plus est détecté.
2. **Immutabilité** — pas de réécriture silencieuse des preuves et des décisions.
3. **`doctor.sh`** — vérifie hooks, gate, revue, état, propreté du dépôt en quelques secondes.

Aucun des trois ne dépend du modèle. C'est le critère : si la mémoire ne peut être vérifiée que
par un agent qui se souvient, ce n'est pas de la mémoire, c'est du contexte.
