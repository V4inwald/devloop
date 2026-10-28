---
id: task-015
status: done
branch: task/015-harness-improvement-skill
created: 2026-10-27
owner: lead
implementer: lead
---

# Skill `harness-improvement` et règles opératoires dans `AGENTS.md`

## Outcome

Une skill `harness-improvement` versionnée décrit la boucle baseline → propose → probe → compose
adaptée à ce dépôt, et `AGENTS.md` gagne cinq règles opératoires courtes plus la ligne de
déclenchement qui rend la skill découvrable — sans dépasser 150 lignes.

## Acceptance criteria

- [x] AC1: `.agents/skills/harness-improvement/SKILL.md` a un front-matter `name` égal au nom du
      dossier, plus `description` et `whenToUse` (`head -6`).
- [x] AC2: `AGENTS.md` contient la chaîne `harness-improvement` et une section
      `## 11. Operating rules` avec exactement 5 règles numérotées
      (`grep -c '^[0-9]\. \*\*' AGENTS.md` → 5).
- [x] AC3: `wc -l < AGENTS.md` ≤ 150.
- [x] AC4: `diff -r .agents/skills dist/devloop-skill/assets/.agents/skills` et
      `diff -q AGENTS.md dist/devloop-skill/assets/AGENTS.md` ne produisent aucune sortie.
- [x] AC5: `bash scripts/devloop/gate.sh` sort 0 sur un arbre propre, résultat lié au SHA.
- [x] AC6: une revue indépendante approuve ce SHA avec `contract: approved` (AGENTS.md est un
      chemin de contrat).
- [x] AC7: aucune règle existante n'est supprimée ; les seules coupes sont §3 (1 ligne), §7
      (2 lignes), §8 (2 lignes), listées dans « Notes ».

## Scope

Touched: `.agents/skills/harness-improvement/SKILL.md`, `AGENTS.md`,
`dist/devloop-skill/assets/.agents/skills/harness-improvement/SKILL.md`,
`dist/devloop-skill/assets/AGENTS.md`, `docs/tasks/task-015.md`.

Out of scope: `scripts/devloop/**`, `.devloop.conf`, `tests/**`, `README.md`, `docs/STATE.md`.

## Verification plan

1. `bash scripts/devloop/gate.sh` — lint + suite d'assertions.
2. Contrôle manuel des règles fatales tant que `harness-check.sh` n'existe pas (task-016) :
   nom de skill verbatim dans `AGENTS.md`, aucun `{{`/`{%`.
3. `bash scripts/devloop/packet.sh`, puis revue par un contexte séparé.

## Risks

- `AGENTS.md` est contractuel : une revue sans `contract: approved` fait refuser l'intégration.
- Le miroir `dist/` compte deux fois dans `MAX_DIFF_LINES` ; un oubli rend `tests/run.sh` rouge.
- Le texte toujours-actif est un coût permanent : dépasser 150 lignes est un échec, pas un détail.

## Notes / decisions

- 2026-10-27: coupes décidées — §8 (4 étapes → une phrase, −2 l.), §7 (fusion des deux dernières
  puces, −2 l.), §3 (puce gate condensée, −1 l.). Aucune règle retirée.
- 2026-10-27: la skill est en anglais, comme les trois skills existantes ; les notes de recherche
  restent hors dépôt (`research/`, exclu localement).
- 2026-10-27: la skill référence `docs/harness/PROBES.md` avec une réserve explicite tant que
  `task-017` ne l'a pas créé.
