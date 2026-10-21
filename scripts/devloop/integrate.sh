#!/usr/bin/env bash
# Merge the current task branch into MAIN_BRANCH, but only with fresh evidence.
#
# Refuses unless ALL hold:
#   1. current branch is not a protected branch;
#   2. working tree is clean;
#   3. a passing, non-dirty gate result exists for HEAD;
#   4. an approving review file exists whose `sha:` covers HEAD. The only commits
#      allowed after the reviewed SHA are additions under docs/reviews/ (the review
#      file itself). Any code move after review invalidates it.
#   5. the diff stays within MAX_DIFF_LINES (unless --allow-oversized).
#   6. when REQUIRE_CI=true, GitHub check-runs are green for HEAD.
#
# Usage: integrate.sh --task <id> [--allow-oversized] [--dry-run]
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
need jq

TASK=""
ALLOW_OVERSIZED=0
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --task) TASK="${2:-}"; shift 2 ;;
    --allow-oversized) ALLOW_OVERSIZED=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$TASK" ] || die "usage: integrate.sh --task <id> [--allow-oversized] [--dry-run]"

BRANCH="$(current_branch)"
SHA="$(head_sha)"
BASE="$(merge_base)"

for b in $PROTECTED_BRANCHES; do
  [ "$BRANCH" != "$b" ] || die "refusing to integrate from protected branch '$b'"
done
is_dirty && die "working tree is dirty; commit or stash before integrating"

GATE="$ART/gate/$SHA/result.json"
[ -f "$GATE" ] || die "no gate result for $SHA; run scripts/devloop/gate.sh"
[ "$(jq -r .ok "$GATE")" = "true" ] || die "gate failed for $SHA; see $GATE"
[ "$(jq -r .dirty "$GATE")" = "false" ] || die "gate ran on a dirty tree; commit and re-run gate.sh"

# --- review evidence -------------------------------------------------------
REVIEW_FILE=""
REVIEWED_SHA=""
for f in $(ls -1t docs/reviews/*.md 2>/dev/null || true); do
  v_sha="$(fm "$f" sha)"
  v_verdict="$(fm "$f" verdict)"
  v_blockers="$(fm "$f" blockers)"
  [ -n "$v_sha" ] || continue
  [ "$v_verdict" = "approve" ] || continue
  [ "$v_blockers" = "0" ] || continue
  git cat-file -e "${v_sha}^{commit}" 2>/dev/null || continue
  if [ "$v_sha" = "$SHA" ]; then
    REVIEW_FILE="$f"; REVIEWED_SHA="$v_sha"; break
  fi
  if git merge-base --is-ancestor "$v_sha" "$SHA" 2>/dev/null; then
    post="$(git diff --name-only "$v_sha..$SHA")"
    offenders="$(printf '%s\n' "$post" | grep -vE '^docs/reviews/' || true)"
    if [ -z "$offenders" ]; then
      REVIEW_FILE="$f"; REVIEWED_SHA="$v_sha"; break
    fi
  fi
done
[ -n "$REVIEW_FILE" ] || die "no approving review for HEAD $SHA; run the code-review step (docs/reviews/)"

if [ "$REVIEWED_SHA" != "$SHA" ]; then
  echo "devloop: review covers $REVIEWED_SHA; later commits touch only docs/reviews/ (allowed)"
fi

# --- size ------------------------------------------------------------------
LINES="$(diff_lines "$BASE")"
if [ "$LINES" -gt "$MAX_DIFF_LINES" ] && [ "$ALLOW_OVERSIZED" -eq 0 ]; then
  die "diff is $LINES lines, above MAX_DIFF_LINES=$MAX_DIFF_LINES; split the task or pass --allow-oversized"
fi

# --- CI (optional, needs an authenticated gh + a remote) -------------------
if [ "$REQUIRE_CI" = "true" ]; then
  command -v gh >/dev/null 2>&1 || die "REQUIRE_CI=true but gh is not installed"
  gh auth status >/dev/null 2>&1 || die "REQUIRE_CI=true but gh is not authenticated"
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)" || die "cannot resolve GitHub repo"
  STATE="$(gh api "repos/$REPO/commits/$SHA/check-runs" \
    --jq '[.check_runs[].conclusion] | if length==0 then "none" elif all(.=="success" or .=="neutral" or .=="skipped") then "green" else "red" end')"
  [ "$STATE" = "green" ] || die "CI is not green for $SHA (state: $STATE)"
else
  echo "devloop: REQUIRE_CI=false, GitHub checks not queried (branch protection should still require CI)"
fi

echo "devloop: evidence complete for $SHA"
echo "  gate:   ${GATE#"$ROOT"/}"
echo "  review: $REVIEW_FILE"
echo "  diff:   $LINES lines (limit $MAX_DIFF_LINES)"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "devloop: dry run, nothing merged"
  exit 0
fi

# --- merge -----------------------------------------------------------------
git checkout -q "$MAIN_BRANCH"
git merge --no-ff "$BRANCH" \
  -m "chore(merge): integrate $TASK ($BRANCH)" \
  -m "Reviewed-by: $REVIEW_FILE" \
  -m "Gate: $SHA"
MERGE_SHA="$(head_sha)"

mkdir -p "$ART/integrations"
jq -n --arg task "$TASK" --arg branch "$BRANCH" --arg reviewed "$REVIEWED_SHA" \
  --arg head "$SHA" --arg merge "$MERGE_SHA" --arg review "$REVIEW_FILE" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{task:$task,branch:$branch,reviewed_sha:$reviewed,head_sha:$head,merge_sha:$merge,review:$review,integrated_at:$ts}' \
  > "$ART/integrations/$MERGE_SHA.json"

echo "devloop: merged $BRANCH into $MAIN_BRANCH at $MERGE_SHA"
echo "next: update docs/STATE.md, then run scripts/devloop/doctor.sh"
