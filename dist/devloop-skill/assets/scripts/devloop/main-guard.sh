#!/usr/bin/env bash
# Fail when a push to main is not a verified pull-request merge.
#
# Env: REPO (owner/name), SHA (pushed head), ACTOR, BEFORE, BASE_BRANCH
#      (default: main), GH_TOKEN for gh. Requires an authenticated gh.
#
# This is the body of .github/workflows/main-guard.yml; keeping it in a script
# makes the failure paths testable with a stub gh (tests/run.sh).
set -euo pipefail

REPO="${REPO:?REPO is required}"
SHA="${SHA:?SHA is required}"
ACTOR="${ACTOR:-unknown}"
BEFORE="${BEFORE:-unknown}"
BASE_BRANCH="${BASE_BRANCH:-main}"

zero=0000000000000000000000000000000000000000
if [ "$SHA" = "$zero" ]; then
  echo "branch deletion, nothing to check"
  exit 0
fi

subject="$(gh api "repos/$REPO/commits/$SHA" --jq '.commit.message' 2>/dev/null | head -1 || true)"
echo "head: $SHA"
echo "subject: ${subject:-<unreadable>}"
reason=""
if [ -z "$subject" ]; then
  reason="cannot read commit $SHA (API failure)"
else
  pr="$(printf '%s' "$subject" | sed -nE 's/^Merge pull request #([0-9]+) from .*/\1/p')"
  if [ -z "$pr" ]; then
    reason="head is not a pull-request merge commit"
  else
    merged="$(gh pr view "$pr" --repo "$REPO" --json state,mergeCommit,baseRefName \
      --jq '.state + "\t" + (.mergeCommit.oid // "") + "\t" + .baseRefName' 2>/dev/null || true)"
    if [ -z "$merged" ]; then
      reason="cannot read PR #$pr (unknown PR or API failure)"
    else
      state="$(printf '%s' "$merged" | cut -f1)"
      oid="$(printf '%s' "$merged" | cut -f2)"
      base="$(printf '%s' "$merged" | cut -f3)"
      if [ "$state" != "MERGED" ]; then
        reason="PR #$pr state is $state"
      elif [ "$oid" != "$SHA" ]; then
        reason="PR #$pr merge commit is $oid, not $SHA"
      elif [ "$base" != "$BASE_BRANCH" ]; then
        reason="PR #$pr was merged into $base, not $BASE_BRANCH"
      else
        echo "PR #$pr merged at $SHA into $BASE_BRANCH"
        exit 0
      fi
    fi
  fi
fi

body="$(printf 'A push to `main` was not a verified pull-request merge.\n\n- head: `%s`\n- actor: `%s`\n- before: `%s`\n- reason: %s\n- commit: https://github.com/%s/commit/%s\n\nThis is a **detection** control; branch protection is the prevention. Inspect, revert if needed, and use `scripts/devloop/integrate.sh --pr`.\n' "$SHA" "$ACTOR" "$BEFORE" "$reason" "$REPO" "$SHA")"
gh issue create --repo "$REPO" --title "Direct push detected on main: ${SHA:0:12}" --body "$body" || true
echo "::error::direct push detected: $reason"
exit 1
