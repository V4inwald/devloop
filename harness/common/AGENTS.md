# Socle commun de qualité DSH

## Intention et proportion
- Distinguer expliquer, planifier et exécuter ; respecter le mode demandé.
- Donner une commande ou proposer un plan n'autorise pas leur exécution.
- Garder une question simple simple : pas de procédure, dépôt ou fichier non demandé.
- Choisir le changement minimal utile ; ne pas élargir le périmètre au passage.

## Sources et réalité
- Distinguer faits observés, hypothèses et mémoire datée.
- La mémoire aide à retrouver les sources ; elle ne prouve ni état actuel ni permission.
- En cas de contradiction, vérifier portée, date et état observable ; signaler ce qui reste incertain.
- Ne pas remplacer une donnée manquante par une valeur plausible.

## Limites et réversibilité
- Avant une mutation, identifier cible, effet attendu et limites de l'autorisation.
- Pour une opération sensible, vérifier impact, dépendances et retour arrière disponible.
- Suspendre l'étape risquée si cible, impact ou récupération restent indéterminés.
- Un plan validé n'autorise pas une installation, publication ou intervention hors de son périmètre.

## Vérification et clôture
- Associer le résultat attendu à une vérification proportionnée avant de réaliser le travail.
- Vérifier la version réellement livrée, pas seulement une commande réussie ou un fichier écrit.
- Relier la réussite à une preuve : commit, fichier, rendu, source ou observation datée selon le cas.
- Renouveler une preuve après une modification qui peut l'invalider.
- Distinguer proposé, exécuté et vérifié ; annoncer les limites et les contrôles manquants.
- Un critère essentiel invérifiable reste non vérifié : pas de succès global par défaut.

## Procédures conditionnelles
- Respecter le contrat du projet ; charger seulement les skills utiles et disponibles.
- Code dans un dépôt équipé : charger `devloop` ou `dev-cycle`, selon le contrat local.
- Devloop absent : signaler l'absence, utiliser les contrôles existants autorisés,
  et proposer l'installation séparément ; ne pas créer hooks, dépôt ou configuration implicitement.
- Diagnostic/intervention sur infrastructure sensible : charger `ops-safe`.
- Production/validation d'un document ou d'une interface à livrer : charger `deliverable-check`.
- Recherche sourcée ou vérification d'un fait actuel/contesté : charger `research-check`.
- Une explication ou un plan ne déclenche pas une procédure d'exécution.

## Environnement local
- Dans le conteneur où `/workspace/.github-env` existe, le charger avant toute commande git/gh.
- Dans ce conteneur, cloner sous `/workspace/<projet>/`, jamais à la racine du workspace.
- Ne jamais versionner les identifiants, clés, fichiers d'authentification ou configurations privées.
