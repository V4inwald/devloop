# Qualité des agents — sources, activation et preuves

## Architecture retenue

| Exigence | Source versionnée | Activation | Vérification |
|---|---|---|---|
| Mode, périmètre, preuves, incertitudes | `harness/common/AGENTS.md` | futur AGENTS global DSH | découverte réelle + sondes de comportement |
| Contraintes de développement du projet | `AGENTS.md` | racine du dépôt | gate et revue du contrat |
| Cycle code | skill devloop puis skills du projet | code demandé, dépôt équipé | tests, revue et SHA |
| Opérations sensibles | `harness/common/skills/ops-safe/SKILL.md` | diagnostic/intervention explicite | service consommé, dépendances et repli |
| Livrable documentaire/interface | `harness/common/skills/deliverable-check/SKILL.md` | production/validation finale | contenu et rendu de la version livrée |
| Recherche sourcée | `harness/common/skills/research-check/SKILL.md` | recherche ou fait actuel/contesté | sources lues, dates et incertitudes |
| Version réellement utilisée | futur manifeste de distribution | installation explicite | comparaison des empreintes source/cible |

Un fichier présent n'est pas forcément chargé. Les skills de ce kit ne sont pas
installés dans le profil par ce commit. Le lot de distribution doit préserver
les skills existants, obtenir l'accord de l'opérateur et vérifier le catalogue.
Les règles du projet ne doivent pas annuler le respect du mode demandé : P1b et
la règle d'exécution trop large ont donc été corrigées ensemble.

## Limites et prochaines preuves

- Les tests structurels vérifient la cohérence des fichiers, pas l'obéissance du modèle.
- Les barrières sensibles doivent aussi vivre dans permissions, CI ou contrôles serveur.
- Un gate vert prouve les contrôles configurés, pas la qualité générale du produit.
- Conserver devloop spécialisé : pas de dépôt, hook, commit ou déploiement implicite.
- Consigner les observations des contextes neufs dans `docs/tasks/task-020.md`.
- Évaluer ensuite mémoire périmée, lien requis manquant, service sensible simulé,
  dépôt sans devloop et question simple ; ne pas annoncer ces scénarios comme exécutés.
