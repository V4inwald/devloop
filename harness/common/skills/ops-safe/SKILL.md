---
name: ops-safe
description: Diagnostiquer ou modifier une infrastructure sensible avec état initial, impact, repli et vérification du service réel.
whenToUse: Diagnostic explicite d'incident ou intervention demandée sur réseau, stockage, VM, conteneur, authentification ou service partagé.
---

# Opérations sûres

## Déclenchement
Diagnostic d'incident ou intervention sur une infrastructure dont dépendent accès,
données ou autres services : redémarrage, bascule, migration, restauration.

## Non-déclenchement
Explication, commande à copier ou plan sans intervention ; simple lecture d'un
capteur ou action domestique triviale sans dépendance sensible.

## Procédure
1. Identifier cible exacte, objectif et autorisation : diagnostic ou intervention.
   Observer l'état actuel et les dépendances critiques, sans les déduire de mémoire.
2. Évaluer interruption, perte de données et perte d'accès. Vérifier le repli et
   ses prérequis ; poser une question ciblée avant l'étape risquée si nécessaire.
3. Commencer par les contrôles non modifiants autorisés. Un diagnostic qui écrit,
   redémarre ou déclenche une charge significative est déjà une intervention.
4. Modifier par petite étape dans le périmètre accepté. En cas de résultat
   inattendu, arrêter les mutations ; ne replier que si cela est prévu et autorisé.
5. Vérifier depuis le consommateur : résolution DNS, accès applicatif ou données,
   pas uniquement le processus. En bascule, vérifier les dépendances et l'absence
   de services concurrents incompatibles, par exemple deux serveurs DHCP.

## Preuves et fin
Rapporter état initial/final, vérification datée du service et dépendances,
actions réalisées, repli disponible et contrôles manquants. « Rétabli » exige
l'effet attendu observé ; sinon annoncer un diagnostic ou une intervention partielle.
Cette procédure n'accorde aucune permission et ne remplace pas les runbooks du site.
