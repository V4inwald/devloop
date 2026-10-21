# 02 — Correspondance avec DeepSeek Harness

Ce document répond à une question précise : **que fournit DSH nativement, que faut-il écrire,
et qu'est-ce qui n'existe pas ?** Les affirmations sont marquées :

- **[V]** vérifié dans cette installation (README du paquet, présence du fichier, ou test réel) ;
- **[S]** supposé ou déduit, à confirmer avant de s'appuyer dessus ;
- **[A]** absent de cette installation.

## Primitives disponibles

| Primitive | État | Détail vérifié | Usage dans le dispositif |
|---|---|---|---|
| `AGENTS.md` | **[V]** natif | paquet `@deepseek-ai/dsh-agent-instructions`, activé par `dsh-base`, budget 65 536 octets, racine projet = présence de `.git`, chaîne de la racine vers le cwd, rechargée au changement de cwd | couche chaude : règles stables |
| Skills locales | **[V]** natif | `@deepseek-ai/dsh-skill` + `dsh-skill-filesystem` ; racines `.dsh/skills` (rang 100) et `.agents/skills` (rang 200) ; `SKILL.md` avec frontmatter `name`/`description` ; rechargement à chaud | procédures : `dev-cycle`, `code-review`, `task-authoring` |
| Sous-agents | **[V]** disponible | outils `subagent` / `subagent_fork`, contexte séparé, paramètre `cwd` | reviewer indépendant, implémenteur isolé |
| Équipe d'agents | **[V]** expérimental | `dsh-experimental-agent-team` + `dsh-experimental-tool-agent-team` ; roster et board durables, stockage de session durable requis, **cwd partagé**, pas de libération automatique des tâches | ordonnancement multi-tâches |
| Worktrees | **[V]** paquet présent, désactivé par défaut | `dsh-experimental-tool-worktree` + runtime ; outil `create_worktree` disponible ici ; change le cwd de la session | isolation par tâche |
| Workflow | **[V]** disponible | outil `workflow` : script JS, phases, `parallel`, `pipeline`, schémas de sortie ; pas d'accès fs/réseau dans le script | fan-out déterministe de tâches indépendantes |
| Ralph | **[V]** outil présent | `dsh-tool-ralph` | moteur d'itération, jamais source de preuve |
| Goal | **[V]** disponible | objectif persistant, rounds de continuation | piloter un projet long, pas une tâche |
| Jobs | **[V]** disponible | commandes longues en arrière-plan | CI longue, suites lentes |
| Auto review | **[V]** expérimental | `dsh-experimental-auto-review` : revue par appel d'outil, avant exécution, en Full access ; peut autoriser à tort | sûreté d'exécution, **pas** revue de code |
| Hooks d'outils | **[A]** | `dsh-hooks-codex`, `dsh-hooks-claude-code` sont des devDependencies, non installés dans `node_modules` | on utilise les hooks git à la place |
| Webhook GitHub | **[A]** | `dsh-webhook-github` devDependency, non installé | phase ultérieure : réveiller un agent sur événement PR |
| Mémoire DSH | **[V]** outils présents | `memory_remember` / `memory_search` disponibles dans la session ; implémentation du stockage non inspectée | pointeurs inter-sessions, pas contenu |

**Correction par rapport à une réponse antérieure** : les paquets `dsh-agent-teams` et
`dsh-devflow` ne sont pas présents dans cette installation. Les paquets réels sont
`dsh-experimental-agent-team` (+ `-tool-` et `-profile`) et, pour la revue automatique par appel,
`dsh-experimental-auto-review`. Ne pas concevoir sur des noms non vérifiés.

## Hiérarchie d'application

| Couche | Contournable ? | Ce qu'on y met |
|---|---|---|
| CI + branch protection | non (côté serveur) | gate, policy, checks requis |
| Hooks git | oui, `--no-verify` | messages de commit, push sur `main`, non-fast-forward |
| Scripts du dépôt | oui, en éditant le script (donc visible en diff) | gate, paquet, intégration, diagnostic |
| Skills | oui, le modèle peut ne pas les charger | procédure, critères de revue |
| `AGENTS.md` | oui, conseil | règles stables, carte mémoire |

**Conclusion opérationnelle** : une règle obligatoire qui n'existe que dans un skill n'est pas
obligatoire. Si elle doit tenir, elle finit dans un script, un hook ou la CI. Les skills servent
à faire bien ce qui est déjà imposé.

## Rôles → primitives

| Besoin | Primitive DSH | Remarque |
|---|---|---|
| Lead qui planifie et route | session principale + `todo_write` | suffisant pour 1 tâche à la fois |
| Implémenteur isolé | `subagent` avec `cwd` sur un worktree | un écrivain par worktree |
| Reviewer indépendant | `subagent` (contexte neuf) ou coéquipier | ne partage pas l'historique de l'implémenteur |
| Parallélisme multi-tâches | `workflow` (fan-out) ou équipe + board | les écrivains restent séparés par worktree |
| Tâches longues / reprise | `goal` + `docs/STATE.md` | l'état fait foi, pas la conversation |
| CI lente | `bash` en job d'arrière-plan puis `job_output` | ne pas bloquer le tour |
| Revue de sûreté par appel | auto review (expérimental) | complément, jamais substitut |

## Concurrence : la contrainte à connaître

Les coéquipiers d'une équipe partagent **un seul cwd**. Deux agents qui écrivent dans le même
worktree produisent des conflits invisibles. Trois options, par ordre de préférence :

1. **Un worktree par tâche**, et des sous-agents avec `cwd` pointant sur leur worktree.
2. **Sérialiser** : une seule tâche en écriture à la fois, les autres en lecture/revue.
3. **Sessions séparées** : chaque session a son cwd, mais la coordination devient manuelle.

Le board d'équipe est un ordonnanceur de session : il n'est pas versionné avec le dépôt. La
source de vérité des tâches reste `docs/tasks/`. Si le board et les fichiers divergent, ce sont
les fichiers qui ont raison.

## Faut-il écrire un plugin ?

**Pas en phase 1.** Un plugin devient nécessaire quand il faut :

- un outil que le modèle **ne peut pas** contourner (retour structuré, refus dans le pipeline
  d'outils), par exemple `devloop_gate` ou `devloop_integrate` ;
- une commande slash `/dev-cycle` qui monte la procédure et le bon preset ;
- un preset d'agent « devloop » (`@deepseek-ai/dsh-agent-preset` : `id` + liste de plugins) qui
  embarque skills, outils d'équipe et consignes ;
- un réveil sur événement GitHub (webhook) pour lancer la revue ou corriger la CI.

Tant que ce sont des scripts bash appelés par un agent, un plugin ajoute du coût de maintenance
sans changer la garantie : un agent qui peut lancer `bash` peut aussi contourner un outil.
La différence devient réelle quand l'outil est le **seul** chemin (le modèle n'a pas de shell
libre) ou quand la CI exécute la même chose.

## Séquence recommandée dans DSH

1. Copier le kit dans le dépôt cible, adapter `.devloop.conf`, installer les hooks.
2. Ouvrir une session DSH dans le dépôt : `AGENTS.md` et les skills sont chargés
   automatiquement (vérifié : les trois skills de ce kit sont apparus dans le catalogue de la
   session sans redémarrage).
3. Démarrer par une tâche courte et réelle, avec un reviewer en sous-agent.
4. Mesurer : taux d'échec du gate, taux de blocage en revue, temps par tâche.
5. Seulement ensuite : preset dédié, plugin d'outils, workflow multi-tâches.

## Limites assumées

- Rien n'empêche un agent malhonnête d'écrire un fichier `verdict: approve`. La défense est la
  séparation de contexte, la trace versionnée, et le contrôle humain par échantillonnage — pas
  une signature cryptographique.
- Le board d'équipe et les artefacts locaux ne survivent pas à un changement de machine. Le
  dépôt, lui, survit : c'est pour cela que l'état et les décisions y sont écrits.
- Les hooks git ne sont pas installés automatiquement après un clone : `install-hooks.sh` doit
  être lancé, et la CI reste le filet de sécurité.
