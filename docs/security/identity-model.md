# Modèle d'identité de la revue

Objectif : une approbation de PR ne doit pas pouvoir être produite par l'agent
qui a écrit le code. Ce document décrit la séparation utilisée par ce dépôt.

## Rôles

| Rôle | Compte | Droits | Ne peut pas |
|---|---|---|---|
| Implémenteur | `comptetest101` | Write sur le dépôt, pas admin | approuver sa propre PR, modifier la protection, pousser sur `main` |
| Reviewer | `V4inwald` (humain ou agent isolé) | lire le code, approuver/demander des changements | — |
| Admin / humain | `V4inwald` | `protect.sh`, réglages, cas à risque | approuver sa propre PR |

La protection de `main` exige **1 approbation** (`REQUIRED_APPROVALS=1`), le
check `gate`, et interdit le push direct, y compris pour les admins.

## Flux

1. L'agent pousse une branche et ouvre une PR (`integrate.sh --pr`).
2. Le check `gate` passe.
3. Si la PR est `REVIEW_REQUIRED`, `integrate.sh --pr` s'arrête avec un message
   explicite : le reviewer approuve (GitHub), puis l'agent relance `--pr`.
4. L'agent merge (il a Write) ; le merge commit est gaté localement avant que
   `main` local ne bouge.

## Isolation du reviewer

Le reviewer doit tourner hors du workspace de l'implémenteur, avec un token
fine-grained limité : `Contents: Read`, `Pull requests: Write`, `Checks: Read`,
`Actions: Read`, `Metadata: Read` ; **pas** `Contents: Write`, **pas**
`Administration`. Le token ne doit jamais être monté dans le workspace de
l'implémenteur. Voir `.reviewer/` pour le container DSH.

## Limites

- Un reviewer IA reste une IA : angles morts, prompt injection dans le diff,
  approbation déléguée. L'humain garde la responsabilité des chemins de contrat
  (`scripts/devloop/`, `.github/workflows/`, `.devloop.conf`, `AGENTS.md`,
  `docs/reviews/`, `docs/tasks/`, `docs/adr/`) et doit auditer.
- `protect.sh` est une action **owner** ; le token de l'agent ne doit pas avoir
  `Administration`.
- Le workspace contient encore la clé SSH owner : pour une isolation complète,
  le reviewer doit tourner sur une autre machine/container et la clé owner ne
  doit pas être accessible à l'implémenteur.
