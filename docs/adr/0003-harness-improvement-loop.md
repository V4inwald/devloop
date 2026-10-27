# 0003 — Boucle d'amélioration du harness (Harness² adapté)

- Statut : accepted
- Date : 2026-10-27
- Décideurs : lead (agent) + owner
- Tâches : task-015, task-016, task-017
- Note : la forme française est volontaire ; les ADR 0001/0002 restent en anglais.

## Contexte

Les instructions des agents (`AGENTS.md`, skills) changeaient sans mesure : aucune baseline, aucun
contraste, aucune règle de forme. Google Harness² (arXiv 2610.14224) montre qu'un harness
s'améliore par une boucle Propose–Probe–Compose sur des **fichiers**, avec des règles de validation
qui rejettent une proposition avant exécution. Notre harness n'offre que deux surfaces
d'**instructions** éditables par un agent — `AGENTS.md` injecté à chaque requête, skills chargées à
la demande — plus des surfaces d'outillage (`scripts/devloop`, `.devloop.conf`) ; le gate est le
seul levier incontournable.

## Décision

1. Adopter trois leviers : règles always-on minimales dans `AGENTS.md` §11, procédure à la demande
   dans la skill `harness-improvement`, contrôles structurels dans le gate (`harness-check.sh`).
2. Toute modification d'instructions suit la boucle : baseline → deux candidats maximum (INV/DOM) →
   sonde → composition ou `KEEP_BASE` → gate et revue indépendante.
3. Le plafond de 150 lignes d'`AGENTS.md` est la contrepartie du texte permanent : on ajoute une
   règle en coupant ailleurs.
4. La boucle est gatée par un humain ; aucune auto-modification autonome.

## Conséquences

- Toute branche qui touche `AGENTS.md` exige une revue `contract: approved`.
- Le gate échouera (task-016) sur une skill orpheline, un `{{`/`{%`, un script nommé absent ou un
  `AGENTS.md` de plus de 150 lignes.
- Les sondes (`docs/harness/PROBES.md`) sont qualitatives : une exécution est une preuve faible.
- Coût : 12 à 16 lignes always-on selon le décompte (titre et blanc compris), un script, une
  skill ; aucune dépendance nouvelle.

## Alternatives écartées

- **Auto-modification autonome** : pas de garde-fou humain, et risque d'optimiser la forme du
  livrable au lieu du travail.
- **Gros pavé de règles always-on** : coût permanent à chaque requête, concurrence le budget de
  sortie ; Harness² place explicitement les composants à la demande avant la prose permanente
  (prompts du dépôt officiel).
- **Benchmark maison avec juge** : pas de budget de rollouts ni de barème fiable dans ce dépôt.

## Suivi

- task-015 : skill + §11. task-016 : `harness-check.sh` dans `CHECK_LINT`. task-017 : sondes + cet
  ADR.
