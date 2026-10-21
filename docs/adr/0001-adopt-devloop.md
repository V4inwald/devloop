# 0001 — Adopt a SHA-bound development loop

- Status: accepted
- Date: 2026-10-21
- Deciders: project owner
- Task: bootstrap

## Context

AI agents can write code faster than a human can supervise, and they systematically over-report
success. A workflow that relies on an agent's own statement ("tests pass", "reviewed") produces
a repository whose history claims more than it can prove. At the same time, heavy enterprise
process would make single-agent work impractical.

The repository needs a loop that is cheap for one agent, strict about evidence, and readable by
the next agent six weeks later.

## Decision

Adopt the devloop contract:

1. **Evidence is bound to a commit SHA.** Gate results and review verdicts name the exact commit
   they cover. Code committed after review invalidates the review.
2. **Gates are scripts, not opinions.** `scripts/devloop/gate.sh` runs the project's own commands
   and records pass/fail; CI runs the same script.
3. **Review is a separate context.** The reviewer never wrote the diff, writes only a verdict
   file, and approves only with zero blockers and per-rubric evidence.
4. **Integration is automated and refuses on missing evidence.** `integrate.sh` merges only with
   a passing clean gate and an approving review covering HEAD.
5. **Memory is layered and versioned.** `AGENTS.md` holds stable rules; skills hold procedures;
   `docs/` holds state, tasks, decisions, reviews and lessons. No hidden memory.
6. **Hooks are convenience, CI is enforcement.** Git hooks are bypassable; CI re-runs policy.

## Consequences

**Positive**

- An agent cannot mark work done without producing artifacts a human can inspect.
- A fresh session can reconstruct context from the repository alone.
- The same commands run locally and in CI, so "works on my machine" is not a category.

**Negative / accepted costs**

- Extra steps per task: task file, gate, review, integration.
- Review adds latency and tokens; two review rounds are the cap before escalation.
- A single-agent workflow still needs a second context for honest review, or explicit
  `reviewer: self` plus human approval.
- Committing the review file moves HEAD, so the gate must run again after the review commit;
  `integrate.sh` tolerates only `docs/reviews/` changes after the reviewed SHA.

**Neutral**

- The tooling is plain bash + git + jq; no service to operate.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Trust the agent's summary | Cannot be audited; fails silently under context loss. |
| Full PR platform from day one | Heavy for one agent; the scripts work locally and CI can reuse them. |
| Store evidence only in CI | Developers cannot integrate offline; CI becomes the only truth. |
| Review by the same agent that implemented | No independence; approval becomes a formality. |

## Follow-up

- Measure review rejection rate and gate failure rate per task; if review never blocks, the
  rubric or the reviewer is not doing its job.
- Add branch protection and required CI checks when the repository gets a remote.
