#!/usr/bin/env bash
# Build the review packet for HEAD: commits, file list, diff, gate evidence.
# The reviewer reads this file instead of reconstructing context with fresh commands.
#
# Usage: packet.sh [<base-rev>]
# Output: .git/devloop/review/<sha>-packet.md (path printed on stdout)
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
need jq

BASE="${1:-$(merge_base)}"
SHA="$(head_sha)"
BRANCH="$(current_branch)"
OUT="$ART/review"
mkdir -p "$OUT"
FILE="$OUT/$SHA-packet.md"

DIFF_FILE="$OUT/$SHA.diff"
git diff "$BASE..HEAD" > "$DIFF_FILE"
TOTAL_LINES="$(wc -l < "$DIFF_FILE" | tr -d ' ')"
CAP=$((MAX_DIFF_LINES * 4))
CHANGED="$(changed_files "$BASE")"
TESTS_TOUCHED="$(printf '%s\n' "$CHANGED" | grep -E '(^|/)tests?/|(^|/)spec/|\.test\.|_test\.' || true)"

{
  echo "# Review packet"
  echo
  echo "- base: \`$BASE\`"
  echo "- head: \`$SHA\`"
  echo "- branch: \`$BRANCH\`"
  echo "- diff lines: $TOTAL_LINES"
  echo "- changed files: $(printf '%s\n' "$CHANGED" | grep -c . || true)"
  echo "- test files touched: ${TESTS_TOUCHED:-none}"
  echo
  echo "## Commits"
  echo '```'
  git log --oneline --no-decorate "$BASE..HEAD"
  echo '```'
  echo
  echo "## Gate evidence for head"
  if [ -f "$ART/gate/$SHA/result.json" ]; then
    jq -r '"ok=\(.ok) dirty=\(.dirty)", (.checks[] | "  \(.name): exit \(.exit)")' \
      "$ART/gate/$SHA/result.json"
  else
    echo "NO GATE RESULT for $SHA. Treat every claim of passing tests as unverified."
  fi
  echo
  echo "## Files"
  echo '```'
  git diff --stat "$BASE..HEAD"
  echo '```'
  echo
  echo "## Diff"
  echo '```diff'
  if [ "$TOTAL_LINES" -le "$CAP" ]; then
    cat "$DIFF_FILE"
  else
    head -n "$CAP" "$DIFF_FILE"
    echo "..."
    echo "[TRUNCATED: $TOTAL_LINES diff lines total, first $CAP shown. Read specific files if needed.]"
  fi
  echo '```'
} > "$FILE"

if [ "$TOTAL_LINES" -gt "$CAP" ]; then
  echo "devloop: warning: diff truncated in packet ($TOTAL_LINES lines > $CAP)" >&2
fi
if [ "$TOTAL_LINES" -gt "$MAX_DIFF_LINES" ]; then
  echo "devloop: warning: diff exceeds MAX_DIFF_LINES=$MAX_DIFF_LINES; integrate.sh will refuse it." >&2
fi
echo "${FILE#"$ROOT"/}"
