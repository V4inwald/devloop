#!/usr/bin/env bash
# Prove that changed tests are red on the pre-change commit.
#
# Usage: prove-red.sh <base-rev> -- <command...>
#
# Copies the test files changed between <base-rev> and HEAD into a detached
# worktree at <base-rev>, runs the command there, and exits 0 only when the
# command fails (the test is red without the change). Exit 1 when the command
# passes on the base (not a regression test), 2 on usage or no changed test.
set -euo pipefail

BASE="${1:-}"
[ -n "$BASE" ] || { echo "usage: prove-red.sh <base-rev> -- <command...>" >&2; exit 2; }
shift || true
[ "${1:-}" = "--" ] && shift
[ $# -gt 0 ] || { echo "usage: prove-red.sh <base-rev> -- <command...>" >&2; exit 2; }
git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null || { echo "devloop: unknown base '$BASE'" >&2; exit 2; }

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
FILES="$(git diff --name-only --diff-filter=ACMR "$BASE...HEAD" \
  | grep -E '(^|/)(tests?|specs?|__tests__)/|\.(test|spec)\.' || true)"
[ -n "$FILES" ] || { echo "devloop: no changed test files vs $BASE" >&2; exit 2; }

WT="$(mktemp -d "${TMPDIR:-/tmp}/devloop-prove-red.XXXXXX")"
cleanup() {
  git worktree remove --force "$WT" >/dev/null 2>&1 || true
  rm -rf "$WT"
}
trap cleanup EXIT
git worktree add -q --detach "$WT" "$BASE" || { echo "devloop: cannot check out $BASE" >&2; exit 2; }

while IFS= read -r f; do
  [ -n "$f" ] || continue
  mkdir -p "$WT/$(dirname "$f")"
  git show "HEAD:$f" > "$WT/$f"
  echo "  copied $f"
done <<< "$FILES"

if ( cd "$WT" && "$@" ); then
  echo "devloop: the command PASSES on $BASE; this is not a red test" >&2
  exit 1
fi
echo "devloop: red confirmed on $BASE ($(printf '%s\n' "$FILES" | wc -l) test file(s))"
