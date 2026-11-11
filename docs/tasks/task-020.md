---
id: task-020
status: ready
branch: task/020-common-guidance
created: 2026-11-11
owner: human
implementer: lead
---

# Un socle commun de qualité, sans imposer devloop à tous les usages

## Outcome

Un kit versionné fournit des instructions globales courtes et trois procédures
conditionnelles pour opérations, livrables et recherche ; devloop reste spécialisé
code. Aucune installation, publication ni action distante n'est implicite.

## Acceptance criteria

- [ ] AC1: harness/common/AGENTS.md distingue expliquer, planifier et exécuter,
  reste sous 60 lignes, et nomme exactement les trois skills livrés et devloop.
- [ ] AC2: chaque skill indique son déclencheur, ses non-déclencheurs, les preuves
  attendues et les limites d'action ; une simple question ne lance pas de cycle.
- [ ] AC3: un contrôle structurel vérifie noms, frontmatter, déclencheurs et budget.
- [ ] AC4: scénarios à contextes neufs pour commande seule et plan sans action ;
  les résultats sont consignés sans prétendre prouver une supériorité générale.
- [ ] AC5: gate propre et revue indépendante ; aucun fichier du profil actif,
  aucun service, aucun paramètre GitHub modifié par ce lot.

## Scope

Touched: harness/common/AGENTS.md, harness/common/skills/*/SKILL.md,
tests/common-guidance.sh, docs/harness/QUALITY-MAP.md, AGENTS.md et son miroir,
docs/harness/PROBES.md (P1b), ce contrat et sa revue.
Out of scope: remplacement du skill harness-improvement, autres procédures historiques,
installateur global, changements de CI, mémoire persistante, secrets, services.
Size estimate: 280–380 lignes ; séparer la distribution dans un autre lot.

## Verification plan / baseline

- Base : 4f0ebbd56572a828c064bbce139bed47da2833a5 ; suite héritée 142/142.
- Constat initial : aucun AGENTS global au DSH_HOME observé (/root/.dsh), skill
  devloop disponible mais plus ancien que le kit du dépôt, catalogue du workspace
  sans procédure dédiée ops/livrables/recherche. Il s'agit d'un écart de couverture
  et de distribution observé, pas d'une preuve d'échec de chaque agent.
- Comparer des scénarios sans effets de bord dans des fixtures distinctes, même
  modèle et environnement ; conserver les limites d'une seule exécution.
- Contrôles structurels, revue du contenu et tests du kit existant.

## Risks / dependencies

Les consignes ne sont pas des permissions ni des barrières techniques. Le kit est
préparé ici, pas activé : le lot de distribution devra vérifier la version réellement
chargée, préserver les skills existants et obtenir l'accord de déploiement global.

## Notes / decisions

L'utilisateur a demandé un socle commun à tous ses usages DSH. Les comportements
universels restent courts ; les procédures détaillées ne sont chargées qu'au besoin.
