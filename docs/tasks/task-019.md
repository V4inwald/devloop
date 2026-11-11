---
id: task-019
status: review
branch: task/019-proof-integrity
created: 2026-11-11
owner: human
implementer: lead
---

# Fiabiliser les preuves locales et le lint shell

## Outcome

Un gate ne certifie pas un commit si ses vérifications déplacent HEAD ou laissent
le dépôt modifié ; le lint analyse chaque script au lieu du seul premier argument.

## Acceptance criteria

- [ ] AC1: `bash tests/proof-integrity.sh` vérifie les codes et les preuves JSON :
  dépôt propre = 0 ; check échoué = 1 ; mutation suivie/non suivie/indexée ou
  changement de HEAD pendant les checks = 3 et aucune preuve propre approuvée.
- [ ] AC2: le JSON conserve le SHA initial, observe le SHA final, et indique un
  changement de HEAD ; les champs existants restent compatibles avec integrate.
- [ ] AC3: le lint refuse une faute de syntaxe dans le deuxième script ou hook,
  et accepte un ensemble valide, y compris un nom de fichier contenant un espace.
- [ ] AC4: la suite existante reste verte ; les nouveaux tests sont exécutés par
  le CHECK_TEST du dépôt et les scripts du bundle correspondent aux sources.
- [ ] AC5: gate propre pour HEAD et revue indépendante avec `contract: approved`.

## Scope

Touched: scripts/devloop/gate.sh, scripts/devloop/lint-shell.sh, .devloop.conf,
tests/proof-integrity.sh, leurs miroirs distribués, ce contrat et sa revue.
Out of scope: intégration/doctor, protections GitHub, PR #20 et fichier local
non suivi du checkout original, installation globale, changement des seuils.
Size estimate: 250–350 lignes ajoutées/supprimées, miroirs compris (<400).

## Verification plan

1. Référence avant modification : `bash tests/run.sh` sur
   `4f0ebbd56572a828c064bbce139bed47da2833a5` : 142 assertions, 0 échec, exit 0.
2. Ajouter les sondes isolées ; les exécuter contre le code de référence et
   consigner les refus absents (aucun changement du dépôt source par la sonde).
3. Corriger, régénérer les miroirs, rejouer les sondes et le gate complet.
4. Faire relire le diff dans un contexte neuf ; soumettre via PR protégée.

## Risks / dependencies

Les checks restent du code de confiance, pas une sandbox : une modification
transitoire puis annulée n'est pas observable par deux instantanés. Les tests
créent des dépôts jetables, n'utilisent ni réseau ni identifiants, et vérifient
les codes/raisons précis plutôt que n'importe quel échec. L'utilisateur a autorisé
les changements de CI/contrôles versionnés le 2026-11-11 ; protections inchangées.

## Notes / decisions

- Baseline ciblée sur le gate d'origine : exit 1, 6 assertions vertes et 14
  rouges (mutations non détectées et helper lint absent). Le contre-exemple
  `bash -n <(printf 'echo valid\n') <(printf 'if\n')` sortait 0 malgré le
  second script invalide : le défaut de lint est observé indépendamment.
- Après correction : `bash tests/proof-integrity.sh` = 24 assertions, 0 échec,
  exit 0 ; `bash scripts/devloop/lint-shell.sh` et `git diff --check` sortent 0.
- Pas d'intégration ni de déploiement avant revue ; état historique non certifié
  par la simple lecture de STATE. Pas de leçon générale déduite d'une seule sonde.
