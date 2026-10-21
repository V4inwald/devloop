#!/usr/bin/env bash
# Diagnose whether the repository's development loop is in a trustworthy state.
# Read-only. Exit 0 when no ERROR is found, 1 otherwise (WARN does not fail).
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
need jq

ERRORS=0
WARNINGS=0
ok()   { echo "  OK    $*"; }
warn() { echo "  WARN  $*"; WARNINGS=$((WARNINGS + 1)); }
err()  { echo "  ERROR $*"; ERRORS=$((ERRORS + 1)); }

echo "devloop doctor: $(head_sha) on $(current_branch)"

if [ "$(git config --get core.hooksPath || true)" = ".githooks" ]; then
  ok "git hooks installed (core.hooksPath=.githooks)"
else
  warn "git hooks not installed; run bash scripts/devloop/install-hooks.sh"
fi

if [ -f .devloop.conf ]; then ok ".devloop.conf present"; else warn ".devloop.conf missing; using defaults"; fi

SHA="$(head_sha)"
INTEGRATION="$(grep -l "\"merge_sha\": \"$SHA\"" "$ART"/integrations/*.json 2>/dev/null | head -1 || true)"

if [ -n "$INTEGRATION" ]; then
  REVIEWED="$(jq -r .reviewed_sha "$INTEGRATION")"
  INTEGRATED_HEAD="$(jq -r .head_sha "$INTEGRATION")"
  ok "HEAD is an integration merge; review covers $REVIEWED, gate covers $INTEGRATED_HEAD"
  if [ -f "$ART/gate/$INTEGRATED_HEAD/result.json" ] \
     && [ "$(jq -r .ok "$ART/gate/$INTEGRATED_HEAD/result.json")" = "true" ] \
     && [ "$(jq -r .dirty "$ART/gate/$INTEGRATED_HEAD/result.json")" = "false" ]; then
    ok "integrated head has a passing clean gate result"
  else
    err "integration record points to missing or failing gate evidence for $INTEGRATED_HEAD"
  fi
  if grep -l "^sha: $REVIEWED$" docs/reviews/*.md >/dev/null 2>&1; then
    ok "review file present for the reviewed SHA"
  else
    err "no review file found for the reviewed SHA $REVIEWED"
  fi
else
  if [ -f "$ART/gate/$SHA/result.json" ]; then
    if [ "$(jq -r .ok "$ART/gate/$SHA/result.json")" = "true" ] \
       && [ "$(jq -r .dirty "$ART/gate/$SHA/result.json")" = "false" ]; then
      ok "passing clean gate result for HEAD"
    else
      err "gate result for HEAD is failing or was produced on a dirty tree"
    fi
  else
    err "no gate result for HEAD; run scripts/devloop/gate.sh"
  fi

  if grep -l "^sha: $SHA$" docs/reviews/*.md >/dev/null 2>&1; then
    ok "review file covers HEAD"
  else
    post_ok=0
    for f in docs/reviews/*.md; do
      [ -f "$f" ] || continue
      s="$(fm "$f" sha)"
      [ -n "$s" ] || continue
      git cat-file -e "${s}^{commit}" 2>/dev/null || continue
      if git merge-base --is-ancestor "$s" "$SHA" 2>/dev/null; then
        off="$(git diff --name-only "$s..$SHA" | grep -vE '^docs/reviews/' || true)"
        [ -z "$off" ] && post_ok=1 && break
      fi
    done
    if [ "$post_ok" -eq 1 ]; then ok "review file covers HEAD (only review docs changed since)"
    else err "no approving review file covers HEAD"; fi
  fi
fi

if [ -f docs/STATE.md ]; then
  state_sha="$(sed -n 's/^last_verified_sha:[[:space:]]*//p' docs/STATE.md | head -1)"
  if [ "$state_sha" = "$SHA" ]; then
    ok "docs/STATE.md verified at HEAD"
  elif [ "$(git rev-parse HEAD^ 2>/dev/null || true)" = "$state_sha" ] \
       && [ -z "$(git diff --name-only "$state_sha..$SHA" | grep -vE '^docs/(STATE|LESSONS)\.md$' || true)" ]; then
    ok "docs/STATE.md verified at HEAD^; HEAD is a bookkeeping commit"
  else
    warn "docs/STATE.md last_verified_sha=${state_sha:-unset} != HEAD; state may be stale"
  fi
else
  warn "docs/STATE.md missing"
fi

if is_dirty; then warn "working tree is dirty; evidence does not describe pending edits"; else ok "working tree clean"; fi

echo "devloop doctor: $ERRORS error(s), $WARNINGS warning(s)"
[ "$ERRORS" -eq 0 ] || exit 1
