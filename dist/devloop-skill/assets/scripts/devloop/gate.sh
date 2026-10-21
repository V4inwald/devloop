#!/usr/bin/env bash
# Run every configured CHECK_* command against HEAD and record a SHA-bound result.
#
# Usage: gate.sh [--task <id>] [--quiet]
# Exit:  0 all checks passed on a clean tree (integrable)
#        1 at least one check failed
#        2 config/usage error
#        3 checks passed but the tree was dirty (NOT integrable)
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
need jq

TASK=""
QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --task) TASK="${2:-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

SHA="$(head_sha)"
BRANCH="$(current_branch)"
DIRTY=false
if is_dirty; then DIRTY=true; fi

OUT="$ART/gate/$SHA"
mkdir -p "$OUT"
: > "$OUT/checks.ndjson"

FAIL=0
COUNT=0
if [ "$QUIET" -eq 0 ]; then
  echo "devloop gate: $SHA on $BRANCH${TASK:+ (task $TASK)}"
fi

for var in $(compgen -A variable | grep '^CHECK_' | sort || true); do
  name="${var#CHECK_}"
  cmd="${!var}"
  [ -n "$cmd" ] || continue
  COUNT=$((COUNT + 1))
  log="$OUT/$name.log"
  start=$SECONDS
  if ( eval "$cmd" ) >"$log" 2>&1; then code=0; else code=$?; fi
  dur=$((SECONDS - start))
  [ "$code" -eq 0 ] || FAIL=1
  jq -nc --arg name "$name" --arg cmd "$cmd" --argjson exit "$code" --argjson s "$dur" \
    '{name:$name,cmd:$cmd,exit:$exit,seconds:$s}' >> "$OUT/checks.ndjson"
  if [ "$QUIET" -eq 0 ]; then
    if [ "$code" -eq 0 ]; then printf '  %-8s PASS  %ss\n' "$name" "$dur"
    else printf '  %-8s FAIL  %ss  (log: %s)\n' "$name" "$dur" "${log#"$ROOT"/}"; fi
  fi
done

if [ "$COUNT" -eq 0 ]; then
  die "no CHECK_* commands configured in .devloop.conf; nothing was verified"
fi

CHECKS_JSON="$(jq -s '.' "$OUT/checks.ndjson")"
OK=false
[ "$FAIL" -eq 0 ] && OK=true

jq -n \
  --arg sha "$SHA" --arg branch "$BRANCH" --arg task "$TASK" \
  --argjson dirty "$DIRTY" --argjson ok "$OK" --argjson checks "$CHECKS_JSON" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{sha:$sha,branch:$branch,task:$task,dirty:$dirty,ok:$ok,checks:$checks,generated_at:$ts}' \
  > "$OUT/result.json"

if [ "$OK" != true ]; then
  if [ "$QUIET" -eq 0 ]; then
    if [ "$DIRTY" = true ]; then
      echo "devloop: gate FAILED on a dirty tree; fix the checks and commit before re-running."
    else
      echo "devloop: gate FAILED -> ${OUT#"$ROOT"/}/result.json"
    fi
  fi
  exit 1
fi

if [ "$DIRTY" = true ]; then
  if [ "$QUIET" -eq 0 ]; then
    echo "devloop: gate UNVERIFIED (checks passed, dirty working tree); this result cannot be integrated."
    echo "devloop: commit the work and re-run -> ${OUT#"$ROOT"/}/result.json"
  fi
  exit 3
fi

[ "$QUIET" -eq 0 ] && echo "devloop: gate PASSED -> ${OUT#"$ROOT"/}/result.json"
exit 0
