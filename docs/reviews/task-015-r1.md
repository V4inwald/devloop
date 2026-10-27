---
task: task-015
sha: d4c873f2c9bc056f92520a79827c111f7dc4a7a3
verdict: approve
blockers: 0
reviewer: reviewer-015
contract: approved
date: 2026-10-27
---

# Review — task-015 round 1

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | AC1: `head -6 .agents/skills/harness-improvement/SKILL.md` → `name: harness-improvement` (equals its directory), `description:` at line 3, `whenToUse:` at line 4. AC2: `grep -c '^[0-9]\. \*\*' AGENTS.md` → `5`; `grep -n 'harness-improvement' AGENTS.md` → `140:`; `## 11. Operating rules (every task)` at `AGENTS.md:126`. AC3: `wc -l < AGENTS.md` → `140` ≤ 150 (`git show main:AGENTS.md \| wc -l` → `128`). AC4: `diff -r .agents/skills dist/devloop-skill/assets/.agents/skills` → rc 0, no output; `diff -q AGENTS.md dist/devloop-skill/assets/AGENTS.md` → rc 0, no output. AC5: `.git/devloop/gate/d4c873f2c9bc056f92520a79827c111f7dc4a7a3/result.json` → `"sha": "d4c873f2…"`, `"dirty": false`, `"ok": true`, LINT exit 0, TEST exit 0; `TEST.log` → `passed: 134, failed: 0`. AC6: this file. AC7: `git diff main..HEAD -- AGENTS.md \| grep '^-'` → only the §3 (3 deleted / 2 added), §7 (3/2), §8 (4/2) hunks plus the `---` header; the same three cuts are listed at `docs/tasks/task-015.md:57-58`. |
| Tests | No test file touched: `git diff --name-only main..HEAD` → 5 files, none under `tests/`. The mechanical mirror this change affects is already asserted by `tests/run.sh:797` (`.agents/skills`) and `tests/run.sh:799` (`AGENTS.md`); TEST passed 134/0. Docs/skill-only change: no executable behaviour to test. |
| Test integrity | `git diff --numstat main..HEAD` → 0 changed lines in any `tests/**` or `scripts/**` path; no assertion removed, no test skipped, no timeout raised. |
| Correctness | Fatal rules checked by hand as the task plans (`docs/tasks/task-015.md:45-46`): `for f in doctor.sh gate.sh integrate.sh packet.sh protect.sh` → 5/5 `OK scripts/devloop/*`; `grep -n '{{\|{%' AGENTS.md` → rc 1 (none). The five §11 rules were compared to §2/§3: no contradiction; one partial overlap (§11.2 vs §2 rule 3) is a finding. The skill's `agent-instructions` claim is real in this harness (`grep -rn 'agent-instructions' /usr/local/lib/node_modules/@deepseek-ai/dsh` → `dsh-agent-instructions` package and client message kind). |
| Errors | Not applicable: no runtime path changed. The only machine-read surface is the YAML front-matter; `head -6` shows three plain scalar keys with no `: ` or `#` inside values, so it parses. |
| Security | `grep -rniE '(api[_-]?key\|secret\|password\|bearer )[[:space:]]*[:=]'` on `AGENTS.md`, the new `SKILL.md` and `task-015.md` → rc 1 (no match). No input boundary, no authz, no path traversal surface in a documentation change. |
| Compatibility | `AGENTS.md` is loaded on every request; the change is additive (§11) plus compression in §3/§7/§8, and `dist/devloop-skill/assets/AGENTS.md` is byte-identical, so installed copies stay in sync. No public API, schema or format change. |
| Scope | `git diff --name-only main..HEAD` → exactly the five files named at `docs/tasks/task-015.md:36-38`; `scripts/devloop/**`, `.devloop.conf`, `tests/**`, `README.md`, `docs/STATE.md` untouched. Size: `git diff --numstat main..HEAD \| awk '{s+=$1+$2} END{print s}'` → `356` ≤ 400, the metric `integrate.sh:166` uses (`common.sh:92-94`); the packet's `diff lines: 424` is `git diff \| wc -l` text lines and is a warning only. |
| Readability | `wc -l .agents/skills/harness-improvement/SKILL.md` → 115 lines, eight short sections, one table per concept, checklists; each §11 rule is two lines and starts with an imperative. |
| Docs | Trigger recorded at `AGENTS.md:139-140` (names the skill verbatim, the fatal-rule shape); decisions at `docs/tasks/task-015.md:57-62`; forward references are explicit: `SKILL.md:37-38` "if it does not exist yet" for `docs/harness/PROBES.md` (absent, `test -e` rc 1) and `SKILL.md:71` "once task-016 lands" for `harness-check.sh` (absent, `test -e` rc 1). |

## Blockers

None.

## Findings (non-blocking)

- `AGENTS.md:100-101` — the §7 fusion drops the words "to the human" and "never a shared draft". The escalation target is defined by §9 (`AGENTS.md:108`) and the draft ban survives in the bullet above (`AGENTS.md:95`), so no rule is lost; restoring "never a shared draft" (+4 words) would keep the text literal. No behavioural impact on this change.
- `docs/tasks/task-015.md:57-58` (and AC7 at `:31-32`) — the Notes claim §7 costs "−2 l."; the actual cut is −1 (3 lines replaced by 2; §3 −1, §8 −2; total −4 cut, +16 added, 128 → 140 lines). AC7's substance — only §3/§7/§8 cut, no rule removed, all listed — holds; the count is off by one.
- `AGENTS.md:130` vs §2 rule 3 (`AGENTS.md:11` onward) — §11.2 "Evidence before claim" overlaps §2's "Evidence over claims"; §2 scopes it to integration evidence (gate + review), §11.2 to a report. Complementary today; keep them in sync if §2 changes.
- `.agents/skills/harness-improvement/SKILL.md:99` — the quoted superlative "the rule the official harness calls 'the most violated'" is not traceable to the repository provenance: `research/01-harness2.md:44` records only "An unnamed skill is never opened anyway". Cite the paper section (the HTML fetch I could run reached §3 only) or drop the quoted clause; the actionable rule above it is correct.
- `.agents/skills/harness-improvement/SKILL.md:77-78` (fatal rule 3: "Every script named in `AGENTS.md` or a `SKILL.md` exists") contradicts this skill's own reference to `harness-check.sh` (`:71`), which does not exist yet (`test -e scripts/devloop/harness-check.sh` → rc 1). The "once task-016 lands" hedge keeps it honest and the contradiction disappears when the script lands; if you want it literal now, scope rule 3 to scripts named as existing.
- Nitpick: `SKILL.md:31` says "if you add a line, cut a line", while this change adds 16 lines to §11 and cuts 4 (+12 net). AC3 (≤150) is respected at 140; the guidance is prospective, but the mismatch is worth a sentence in task-016's checker.
- Nitpick: no automated assertion yet for the 150-line ceiling or the skill front-matter; `docs/tasks/task-015.md:44-47` delegates that to manual checks until `harness-check.sh` (task-016). Acceptable for a docs-only change.

## Verdict rationale

Every acceptance criterion is backed by a command result on `d4c873f2c9bc056f92520a79827c111f7dc4a7a3`: the skill front-matter names its directory, `AGENTS.md` carries exactly five numbered operating rules at 140 lines, both `dist/` mirrors are empty diffs, and the stored gate artifact names this SHA with `dirty: false` and 134 passing assertions. The contract-path judgement is positive: §3/§7/§8 are compressed, never weakened — the escalation target and the draft ban are both still stated, one section away and one bullet above. The remaining findings are wording and provenance issues that do not change what an agent must do; the one factual slip, the §7 line count in the task Notes, is documentation-only and does not affect acceptance. Per the review brief I did not re-run the gate: I verified the stored artifact against HEAD and its `generated_at` timestamp, which is the evidence `integrate.sh` reads.
