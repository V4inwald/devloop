#!/usr/bin/env bash
# Structural checks on the agent instruction surface — the Harness2 fatal
# rules, adapted to this kit.
#
#   1. every .agents/skills/<name>/ is named verbatim in AGENTS.md;
#   2. AGENTS.md contains no template syntax ({{ or {%): the always-on text is
#      rendered strictly, and a placeholder kills the run before work starts;
#   3. every scripts/.../*.sh named in AGENTS.md or a SKILL.md exists;
#   4. AGENTS.md stays at or under MAX_AGENTS_LINES, the price of always-on text.
#
# Usage: harness-check.sh [--root <dir>] [-q]
# Exit: 0 all rules pass, 1 at least one failure, 2 usage or configuration error.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MAX_AGENTS_LINES=150
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    -q) QUIET=1; shift ;;
    *) printf 'usage: harness-check.sh [--root <dir>] [-q]\n' >&2; exit 2 ;;
  esac
done

if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  printf 'harness-check: --root is not a directory: %s\n' "${ROOT:-<empty>}" >&2
  exit 2
fi

AGENTS="$ROOT/AGENTS.md"
FAILS=0
fail() { FAILS=$((FAILS + 1)); printf 'FAIL: %s\n' "$*"; }

if [ ! -f "$AGENTS" ]; then
  printf 'FAIL: AGENTS.md missing at %s\n' "$AGENTS"
  exit 1
fi

# 1. every skill must be named verbatim in the always-on text.
SKILL_COUNT=0
if [ -d "$ROOT/.agents/skills" ]; then
  for dir in "$ROOT"/.agents/skills/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    SKILL_COUNT=$((SKILL_COUNT + 1))
    grep -qF -- "$name" "$AGENTS" || fail "skill '$name' is not named verbatim in AGENTS.md"
  done
fi

# 2. no template syntax in the always-on text.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  fail "AGENTS.md has template syntax at line ${hit%%:*}"
done < <(grep -nE '\{\{|\{%' "$AGENTS" 2>/dev/null || true)

# 3. every named helper script must exist.
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  [ -f "$ROOT/$rel" ] || fail "named script '$rel' does not exist"
done < <(
  {
    grep -ohE 'scripts/[A-Za-z0-9_./-]+\.sh' "$AGENTS" 2>/dev/null || true
    grep -rhoE 'scripts/[A-Za-z0-9_./-]+\.sh' "$ROOT/.agents/skills" 2>/dev/null || true
  } | sort -u
)

# 4. always-on budget.
LINES="$(wc -l < "$AGENTS" | tr -d '[:space:]')"
[ "${LINES:-0}" -le "$MAX_AGENTS_LINES" ] \
  || fail "AGENTS.md has $LINES lines (limit $MAX_AGENTS_LINES)"

if [ "$FAILS" -eq 0 ]; then
  [ "$QUIET" -eq 1 ] \
    || printf 'harness-check: OK (%s skills, AGENTS.md %s lines)\n' "$SKILL_COUNT" "$LINES"
  exit 0
fi
printf 'harness-check: %d failure(s)\n' "$FAILS"
exit 1
