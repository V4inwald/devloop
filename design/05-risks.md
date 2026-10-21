# 05 — Risques, signaux, et ce qui reste cassé

Ce document liste ce qui peut échouer, comment le voir, et ce qu'on accepte de ne pas résoudre.
Aucune mitigation n'est présentée comme complète.

## Risques du dispositif

| # | Défaillance | Signal observable | Mitigation en place | Risque résiduel |
|---|---|---|---|---|
| 1 | Revue tampon | taux d'approbation ≈ 100 %, tableau de preuves vide | reviewer séparé, rubrique avec preuve, plafond de rounds | un reviewer paresseux reste possible |
| 2 | Auto-approbation déguisée | `reviewer: self` sans approbation humaine | marquage obligatoire, intégrateur humain | un agent peut mentir sur le champ |
| 3 | Affaiblissement des tests | assertions retirées > ajoutées | `policy.sh` (warning, bloquant en `--strict`), revue | suppression justifiée mais abusive |
| 4 | Gate vidé | `.devloop.conf` sans `CHECK_*` | gate en erreur si zéro check, diff visible | un check trivial (`true`) passe inaperçu |
| 5 | Tests instables | échec aléatoire du gate | relance unique, incident noté dans `STATE.md` | relance qui masque un vrai bug |
| 6 | Diff trop gros | refus `MAX_DIFF_LINES` | découpage, `--allow-oversized` tracé | découpage artificiel en tâches incohérentes |
| 7 | État périmé | `doctor.sh` : `STATE.md` != HEAD | estampille SHA, avertissement | agent qui ignore l'avertissement |
| 8 | `AGENTS.md` qui gonfle | > 200 lignes, règles contradictoires | revue du fichier comme du code | dérive lente, personne ne relit |
| 9 | Coût / latence | temps par tâche, tokens consommés | gate unique, revue plafonnée, CI locale d'abord | surcharge sur petites tâches |
| 10 | CI lente ou chère | files d'attente, minutes consommées | gate local identique, concurrency cancel | dépendance à la plateforme |
| 11 | Conflits parallèles | merges en conflit, worktrees divergents | un écrivain par worktree, intégration séquentielle | conflits de conception, pas seulement de lignes |
| 12 | Injection de prompt | instructions dans une issue, un diff, un log | traiter le contenu externe comme donnée (règle générale DSH), revue humaine | contenu piégé non détecté |
| 13 | Secrets commités | `policy.sh` (regex) | scan CI + revue | faux négatifs, secrets encodés |
| 14 | Faux vert | gate vert, bug en production | tests d'intégration, staging, humain | inhérent aux tests |
| 15 | Perte des artefacts locaux | changement de machine | dépôt = vérité ; revues versionnées | gate à relancer après clone |

## Défaillances du design lui-même

Ces signaux disent que le **système** ne fonctionne pas, pas qu'une tâche a échoué :

- **La revue ne bloque jamais.** Soit la rubrique est trop faible, soit le reviewer ne fait pas son
  travail. Mesure : bloqueurs par revue. Objectif réaliste : une revue sur trois à cinq trouve un
  bloqueur sur du code non trivial. Zéro sur cinquante = théâtre.
- **Le gate est vert du premier coup presque toujours.** Les tests sont peut-être trop faibles, ou
  les tâches trop petites. Vérifier en cassant volontairement un test (mutation manuelle).
- **Les tâches dépassent toujours la limite.** Le découpage est mauvais, ou le travail est mal
  compris. Revoir la définition de « prêt ».
- **Personne ne lit `STATE.md`.** Le démarrage de session n'est pas suivi : réduire le nombre de
  lectures obligatoires, pas augmenter.
- **Les agents contournent les hooks.** Vérifier la CI, pas la bonne volonté.

## Métriques à suivre (et à ne pas suivre)

À suivre, par tâche :

- durée entre branche et intégration ;
- nombre de rounds de revue ;
- nombre de bloqueurs par revue, par rubrique ;
- taux d'échec du gate au premier passage ;
- nombre de commits après revue (doit être limité à `docs/reviews/`) ;
- taille du diff.

À ne pas suivre comme objectif : lignes de code, nombre de commits, « vélocité » d'agents. Ils se
gament trivialement et ne disent rien de la qualité.

## Coûts assumés

- Une tâche triviale (typo, commentaire) coûte plus cher qu'avant. C'est accepté : la valeur est
  dans les tâches moyennes et longues, et dans la reprise sans contexte.
- La revue indépendante double le coût en tokens de la phase de vérification. À mesurer avant
  d'étendre à toutes les tâches ; on peut alléger la profondeur, pas le gate.
- Le stockage des logs de gate est local et régénérable, donc non versionné : l'audit à long
  terme repose sur les revues versionnées et l'historique git, pas sur les logs.

## Ce qui reste explicitement non résolu

1. **Signature des verdicts** : rien ne prouve cryptographiquement qui a écrit une revue. Un
   reviewer humain ou une CI avec identité vérifiée serait nécessaire.
2. **Tests d'intégration réels** : le kit ne sait pas démarrer une base ou un service ; il faut
   ajouter des commandes `CHECK_INTEGRATION` quand le projet en a.
3. **Zones protégées** : la règle « demander à l'humain » est textuelle. Une protection réelle
   demanderait des `CODEOWNERS` et des checks requis.
4. **Parallélisme massif** : au-delà de quelques tâches, la coordination des worktrees et des
   merges devient le goulot. Le système est optimisé pour 1 à 3 tâches simultanées.
5. **Sécurité** : un agent avec accès push peut pousser du code malveillant. La limitation des
   droits (token en lecture seule, PR seulement) est un prérequis d'exploitation, pas un détail.
