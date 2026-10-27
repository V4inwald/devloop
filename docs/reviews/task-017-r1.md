---
task: task-017
sha: 25c49245db8b96e616fab81923c9cbcf68f2180a
verdict: revise
blockers: 1
reviewer: reviewer-017
contract: n/a
date: 2026-10-27
---

# Review — task-017 round 1

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `docs/harness/PROBES.md:17-24` = six rows P1–P6 with PASS and FAIL columns, hardened variants at `:26-32`, baseline at `:34-47`. AC2: SHA at `:34`, P1–P3 verdicts at `:40-42`, honest limit at `:45-47`; the SHA really predates the rules — `git show 8e2e254:AGENTS.md \| grep -c 'Operating rules'` → `0` (and `0` for `harness-improvement`), `git ls-tree 8e2e254:.agents/skills/` contains no `harness-improvement`. AC3: `Statut : accepted` at `docs/adr/0003-harness-improvement-loop.md:3`; Contexte `:7`, Décision `:16`, Conséquences `:26`, Alternatives écartées `:34`. AC4: both paths exist (`test -f .githooks/commit-msg` → rc 0; `test -f scripts/devloop/policy.sh` → rc 0), but the contract's exact command exits 2 → blocker 1. AC5: `.git/devloop/gate/25c49245db8b96e616fab81923c9cbcf68f2180a/result.json` names this SHA, `dirty: false`, `ok: true`, LINT 0, TEST 0; `TEST.log` → `passed: 135, failed: 0`. AC6: this file; r1 is `revise`, so AC6 stays open until r2. |
| Tests | No test changed. Gate TEST `bash tests/run.sh` exit 0, `passed: 135, failed: 0`. Docs-only change: no executable behaviour to test. |
| Test integrity | `git diff --numstat origin/main..HEAD` → 3 files, all under `docs/`, 0 lines under `tests/`; no assertion, skip or timeout touched. |
| Correctness | Verifiable claims checked. arXiv 2610.14224 is Harness² (fetched `https://arxiv.org/html/2610.14224v1` in this session: "Harness2: Recursive Agent Harnessing for an Open World", Google Cloud AI Research). Cited lines are exact: `.githooks/commit-msg:14` is `CONVENTIONAL='^(feat\|fix\|docs\|…'`, `scripts/devloop/policy.sh:21` is the same regex. Baseline versions match this environment: `bash --version` → 5.2.37(1), `git --version` → 2.47.3, `node --version` → v24.22.0. Baseline SHA exists: `git cat-file -e 8e2e254^{commit}` → 0 (`docs(reviews): approve task-014`, 2026-10-23). One verifiable statement is false today: ADR `:29-30` (finding). |
| Errors | Not applicable: no runtime path changed; the three files are static Markdown. |
| Security | `grep -rniE '(api[_-]?key\|secret\|password\|passwd\|token\|bearer)[[:space:]]*[:=]'` on the three files → rc 1 (no match). No secret, no credential. |
| Compatibility | No mirror or contract path touched: `git diff --name-only origin/main..HEAD \| grep -E '^\.agents\|^scripts\|^\.githooks\|^\.github\|^AGENTS\|^\.devloop\|^dist'` → no output; `CONTRACT_PATHS` = `.devloop.conf scripts/devloop .githooks .github/workflows AGENTS.md` (`scripts/devloop/common.sh:23`), so `contract:` is `n/a`. |
| Scope | `git diff --name-only origin/main..HEAD` → exactly the 3 files of the task Scope (`docs/tasks/task-017.md:32-33`); `git diff --numstat origin/main..HEAD` sum → 156 changed lines (`git diff origin/main..HEAD \| wc -l` → 174 text lines), below 400. No code, config or skill changed. |
| Readability | `docs/harness/PROBES.md` 57 lines: 6-row table, 3 hardened variants, baseline table, registration format; ADR 45 lines with the 4 required sections plus Suivi. |
| Docs | ADR records decision, consequences, discarded alternatives and follow-up (`:34-45`); probes record protocol, baseline provenance and the honest limit; task Notes `:51-54` record that P4–P6 were not run and why. |

## Blockers

1. `docs/tasks/task-017.md:26` (AC4) and `docs/tasks/task-017.md:39` (verification plan step 1) — the command `test -f .githooks/commit-msg scripts/devloop/policy.sh` is invalid bash: `test -f` takes a single operand, so it exits 2 with "binary operator expected" (reproduced: exact command → rc 2). It can never produce the "exit 0" the plan promises, even though both paths exist as separate `test -f` runs (rc 0 each). Required fix: write `test -f .githooks/commit-msg && test -f scripts/devloop/policy.sh` in both places — a single edit to the task file.

## Findings (non-blocking)

- `docs/adr/0003-harness-improvement-loop.md:29-30` — "Le gate échoue sur une skill orpheline, un `{{`/`{%`, un script nommé absent ou un `AGENTS.md` de plus de 150 lignes" is false on this SHA: `CHECK_LINT="bash -n scripts/devloop/*.sh && bash -n .githooks/*"` (`.devloop.conf:3`), `test -f scripts/devloop/harness-check.sh` → rc 1, and `grep -rn 'MAX_AGENTS_LINES\|150' .devloop.conf scripts/ tests/run.sh` → no match. task-016 implements it on branch `task/016-harness-check` (review approved at `fca609b`) and ADR `:44` names it; write "échouera (task-016)" so the accepted ADR is literally true.
- `docs/adr/0003-harness-improvement-loop.md:12-14` — "Notre harness n'offre que deux surfaces éditables par un agent" is narrower than the surface map task-015 shipped (`.agents/skills/harness-improvement/SKILL.md:15-16` lists `AGENTS.md`, `.agents/skills/**`, `scripts/devloop/**`, `.devloop.conf`, `docs/**`). If the intent is "two instruction surfaces", say so.
- `docs/adr/0003-harness-improvement-loop.md:38-39` — "Harness² documente cet échec" attributes to the paper a documented failure of large always-on blocks; the repository provenance records only the derived preference to prefer on-demand components (`research/01-harness2.md:94`), not an experiment on always-on size. Cite the paper section or attribute it to this repository's synthesis.
- `docs/adr/0003-harness-improvement-loop.md:3` — `Statut : accepted` satisfies AC3, but the ADR template and ADRs 0001/0002 use `Status:` plus `Deciders` and `Task` fields (`docs/adr/0000-template.md:3-6`); harmonize or record that the French form is deliberate.
- `docs/adr/0003-harness-improvement-loop.md:32` — "~13 lignes always-on": §11 is 16 lines including heading and blank, and AGENTS.md net growth from task-015 was +12 (128 → 140). State 12–16 rather than ~13.
- `docs/harness/PROBES.md:54` — the registration example names `task-015` as if a probe record existed there; `docs/tasks/task-015.md` contains no such line (the baseline ran at `8e2e254`, before task-015). Use `task-NNN` to avoid implying a record that does not exist.
- Nitpick: baseline P2/P3 observations are historical and cannot be replayed; the checkable parts (SHA, versions, cited lines) hold, and the document itself labels one execution as weak evidence.

## Verdict rationale

The substance is sound: six probes with observable PASS/FAIL, a baseline whose SHA genuinely predates the task-015 rules, exact cited lines and versions, an ADR with the required status and sections, 156 documentation lines in scope, no secret, and a fresh gate artifact naming this SHA. Approval is blocked by one contract defect, not by content: the AC4 and verification-plan command errors under bash (rc 2), and acceptance text is never rewritten after integration, so it must be fixed on this branch — which forces a new commit, a new gate and a round 2. The ADR's present-tense gate claim is the nearest second blocker; I keep it a finding because task-016 already implements that gate on its branch and the ADR names it in Suivi — a two-word hedge (`task-016`) removes the ambiguity.
