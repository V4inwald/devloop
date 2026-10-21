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

# Existing installations wrote evidence to <worktree>/.devloop/artifacts. Keep
# reading it (read-only) so an upgrade does not turn a valid repository red.
LEGACY_ART="${DEVLOOP_LEGACY_ARTIFACTS:-$ROOT/.devloop/artifacts}"

gate_json() {
  local f
  f="$ART/gate/$1/result.json"
  [ -f "$f" ] || f="$LEGACY_ART/gate/$1/result.json"
  printf '%s' "$f"
}

# shared | legacy | missing
gate_source() {
  if [ -f "$ART/gate/$1/result.json" ]; then printf 'shared'
  elif [ -f "$LEGACY_ART/gate/$1/result.json" ]; then printf 'legacy'
  else printf 'missing'; fi
}

# ok | dirty | failed | stale | missing
gate_state() {
  local f
  f="$(gate_json "$1")"
  [ -f "$f" ] || { printf 'missing'; return 0; }
  [ "$(jq -r '.sha // empty' "$f" 2>/dev/null || true)" = "$1" ] || { printf 'stale'; return 0; }
  case "$(jq -r '[.ok,.dirty]|@tsv' "$f" 2>/dev/null || true)" in
    $'true\tfalse') printf 'ok' ;;
    $'true\ttrue')  printf 'dirty' ;;
    *)              printf 'failed' ;;
  esac
}

# Print the review file that approves this exact SHA, or nothing.
review_covers() {
  local sha="$1" f s post offenders
  [ -n "$sha" ] || return 0
  for f in docs/reviews/*.md; do
    [ -f "$f" ] || continue
    [ "$(fm "$f" verdict)" = "approve" ] || continue
    [ "$(fm "$f" blockers)" = "0" ] || continue
    s="$(fm "$f" sha)"
    [ -n "$s" ] || continue
    git cat-file -e "${s}^{commit}" 2>/dev/null || continue
    if [ "$s" = "$sha" ]; then printf '%s' "$f"; return 0; fi
    if git merge-base --is-ancestor "$s" "$sha" 2>/dev/null; then
      post="$(git diff --name-only "$s..$sha")"
      offenders="$(printf '%s\n' "$post" | grep -vE '^docs/reviews/' || true)"
      if [ -z "$offenders" ]; then printf '%s' "$f"; return 0; fi
    fi
  done
  return 0
}

echo "devloop doctor: $(head_sha) on $(current_branch)"

HOOKS_PATH="$(git config --get core.hooksPath || true)"
if [ "$HOOKS_PATH" = ".githooks" ] && [ -x .githooks/commit-msg ] && [ -x .githooks/pre-push ]; then
  ok "git hooks installed and executable (core.hooksPath=.githooks)"
elif [ "$HOOKS_PATH" = ".githooks" ]; then
  warn "core.hooksPath is set but .githooks is not executable; run bash scripts/devloop/install-hooks.sh"
else
  warn "git hooks not installed; run bash scripts/devloop/install-hooks.sh"
fi

if [ -f .devloop.conf ]; then ok ".devloop.conf present"; else warn ".devloop.conf missing; using defaults"; fi

case "$ART" in
  "$GIT_COMMON_DIR"/*) ok "shared artifact store ($ART)" ;;
  "$ROOT"/*)           warn "artifact store $ART is inside the worktree; set DEVLOOP_ARTIFACTS outside it" ;;
  *)                   ok "artifact store ($ART)" ;;
esac

SHA="$(head_sha)"
INTEGRATION=""
INTEGRATION_SOURCE=""
for dir in "$ART" "$LEGACY_ART"; do
  for f in "$dir"/integrations/*.json; do
    [ -f "$f" ] || continue
    if [ "$(jq -r '.merge_sha // empty' "$f" 2>/dev/null || true)" = "$SHA" ]; then
      INTEGRATION="$f"
      INTEGRATION_SOURCE="$dir"
      break 2
    fi
  done
done

if [ -n "$INTEGRATION" ]; then
  INTEGRATED_HEAD="$(jq -r '.head_sha // empty' "$INTEGRATION")"
  REVIEWED="$(jq -r '.reviewed_sha // empty' "$INTEGRATION")"
  MERGE_GATE="$(jq -r '.merge_gate // empty' "$INTEGRATION")"
  ok "HEAD is an integration merge (head $INTEGRATED_HEAD, review $REVIEWED)"
  if [ "$INTEGRATION_SOURCE" = "$LEGACY_ART" ]; then
    warn "integration record comes from the legacy store ($LEGACY_ART)"
  fi

  if [ -n "$MERGE_GATE" ]; then
    SRC="$(gate_source "$SHA")"
    [ "$SRC" = "legacy" ] && warn "merge gate evidence comes from the legacy store"
    case "$(gate_state "$SHA")" in
      ok)     ok "merge commit has a passing clean gate result" ;;
      dirty)  err "merge gate was produced on a dirty tree ($SHA)" ;;
      failed) err "merge gate failed ($SHA)" ;;
      stale)  err "merge gate result names another SHA ($SHA)" ;;
      *)      err "merge gate is missing for $SHA; re-run integrate.sh" ;;
    esac
  else
    SRC="$(gate_source "$INTEGRATED_HEAD")"
    [ "$SRC" = "legacy" ] && warn "integrated-head gate evidence comes from the legacy store"
    case "$(gate_state "$INTEGRATED_HEAD")" in
      ok)     ok "integrated head has a passing clean gate (legacy record: merge commit not gated)"
              warn "legacy integration record: re-run the loop to gate the merge commit" ;;
      dirty)  err "integrated head gate was produced on a dirty tree ($INTEGRATED_HEAD)" ;;
      failed) err "integrated head gate failed ($INTEGRATED_HEAD)" ;;
      stale)  err "integrated head gate result names another SHA ($INTEGRATED_HEAD)" ;;
      *)      err "integration record points to missing gate evidence for $INTEGRATED_HEAD" ;;
    esac
  fi

  FILE_FOUND="$(review_covers "$REVIEWED")"
  if [ -n "$FILE_FOUND" ]; then ok "review file $FILE_FOUND covers the reviewed SHA"
  else err "no approving review file covers $REVIEWED"; fi
else
  SRC="$(gate_source "$SHA")"
  [ "$SRC" = "legacy" ] && warn "gate evidence comes from the legacy store ($LEGACY_ART)"
  case "$(gate_state "$SHA")" in
    ok)     ok "passing clean gate result for HEAD" ;;
    dirty)  err "gate result for HEAD was produced on a dirty tree; commit and re-run gate.sh" ;;
    failed) err "gate result for HEAD is failing; see $(gate_json "$SHA")" ;;
    stale)  err "gate result names another SHA; re-run gate.sh" ;;
    *)      err "no gate result for HEAD; run scripts/devloop/gate.sh" ;;
  esac

  FILE_FOUND="$(review_covers "$SHA")"
  if [ -n "$FILE_FOUND" ]; then ok "review file $FILE_FOUND covers HEAD"
  else err "no approving review file covers HEAD"; fi
fi

if [ -f docs/STATE.md ]; then
  STATE_SHA="$(sed -n 's/^last_verified_sha:[[:space:]]*//p' docs/STATE.md | head -1)"
  if [ "$STATE_SHA" = "$SHA" ]; then
    ok "docs/STATE.md verified at HEAD"
  elif [ -n "$STATE_SHA" ] && [ "$(git rev-parse HEAD^ 2>/dev/null || true)" = "$STATE_SHA" ] \
       && [ -z "$(git diff --name-only "$STATE_SHA..$SHA" | grep -vE '^docs/(STATE|LESSONS)\.md$' || true)" ]; then
    ok "docs/STATE.md verified at HEAD^; HEAD is a bookkeeping commit"
  else
    warn "docs/STATE.md last_verified_sha=${STATE_SHA:-unset} != HEAD; state may be stale"
  fi
else
  warn "docs/STATE.md missing"
fi

if is_dirty; then warn "working tree is dirty; evidence does not describe pending edits"; else ok "working tree clean"; fi

echo "devloop doctor: $ERRORS error(s), $WARNINGS warning(s)"
[ "$ERRORS" -eq 0 ] || exit 1
