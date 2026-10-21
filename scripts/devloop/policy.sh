#!/usr/bin/env bash
# Repository policy checks that must hold in CI, where --no-verify cannot help.
#
# Usage: policy.sh [<base-rev>] [--strict]
# Checks: conventional commit subjects, secret-looking additions, test weakening.
# Exit: 0 clean, 1 violations, 2 usage error.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
need jq

STRICT=0
BASE=""
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    -*) die "unknown argument: $arg" ;;
    *) BASE="$arg" ;;
  esac
done
[ -n "$BASE" ] || BASE="$(merge_base)"

CONVENTIONAL='^(feat|fix|docs|test|refactor|perf|build|ci|chore|revert)(\([a-z0-9./_-]+\))?!?: [a-z].{0,67}$'
VIOLATIONS=0
WARNINGS=0

echo "devloop policy: $BASE..HEAD"

while IFS= read -r subject; do
  [ -n "$subject" ] || continue
  case "$subject" in
    "Merge "*|Revert\ \"*) continue ;;
  esac
  if ! printf '%s' "$subject" | grep -Eq "$CONVENTIONAL"; then
    echo "VIOLATION commit subject: $subject"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done < <(git log --format=%s "$BASE..HEAD")

DIFF="$(git diff "$BASE..HEAD")"
SECRETS="$(printf '%s\n' "$DIFF" \
  | grep -nE '^\+[^+].*(api[_-]?key|secret|passwd|password|token)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9_./+-]{16,}' \
  | head -20 || true)"
if [ -n "$SECRETS" ]; then
  echo "VIOLATION possible committed secret:"
  printf '%s\n' "$SECRETS" | sed 's/^/  /'
  VIOLATIONS=$((VIOLATIONS + 1))
fi

REMOVED="$(printf '%s\n' "$DIFF" | grep -cE '^-[^-].*(assert|expect\(|require\.|t\.Fatal|should\.)' || true)"
ADDED="$(printf '%s\n' "$DIFF" | grep -cE '^\+[^+].*(assert|expect\(|require\.|t\.Fatal|should\.)' || true)"
if [ "$REMOVED" -gt "$ADDED" ]; then
  echo "WARNING: $REMOVED assertion lines removed vs $ADDED added; confirm this is not test weakening"
  WARNINGS=$((WARNINGS + 1))
  if [ "$STRICT" -eq 1 ]; then
    echo "VIOLATION (strict): net assertion removal"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
fi

echo "devloop policy: $VIOLATIONS violation(s), $WARNINGS warning(s)"
[ "$VIOLATIONS" -eq 0 ] || exit 1
exit 0
