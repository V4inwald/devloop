#!/usr/bin/env bash
# Configure GitHub branch protection so main can only change through a reviewed,
# CI-green pull request. Requires an authenticated gh with admin on the repo.
#
# Usage: protect.sh [--dry-run] [--no-admins]
# Env: REQUIRED_CHECKS (default "gate"), REQUIRED_APPROVALS (default 0),
#      GH_REPO (owner/name; default: the current repository).
#
# With one GitHub account, REQUIRED_APPROVALS must stay 0: GitHub forbids
# approving your own PR. The file-based review (docs/reviews/) remains the
# process gate; branch protection enforces PR + required CI + no force-push.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
need jq

DRY=0
ENFORCE_ADMINS=true
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --no-admins) ENFORCE_ADMINS=false ;;
    -h|--help) sed -n '2,15p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

REQUIRED_CHECKS="${REQUIRED_CHECKS:-gate}"
REQUIRED_APPROVALS="${REQUIRED_APPROVALS:-0}"
command -v gh >/dev/null 2>&1 || die "protect.sh requires gh"

if [ "$DRY" -eq 1 ]; then
  REPO="${GH_REPO:-<current-repo>}"
else
  gh auth status >/dev/null 2>&1 || die "protect.sh requires an authenticated gh"
  REPO="${GH_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}" || die "cannot resolve the GitHub repo"
  ADMIN="$(gh api "repos/$REPO" --jq '.permissions.admin // false')"
  [ "$ADMIN" = "true" ] || die "the token is not an admin of $REPO"
fi

PAYLOAD="$(jq -n \
  --arg ctx "$REQUIRED_CHECKS" \
  --argjson approvals "$REQUIRED_APPROVALS" \
  --argjson admins "$ENFORCE_ADMINS" \
  '{required_status_checks:{strict:false,contexts:[$ctx]},
    enforce_admins:$admins,
    required_pull_request_reviews:(if $approvals > 0 then {required_approving_review_count:$approvals,dismiss_stale_reviews:true} else null end),
    restrictions:null,
    allow_force_pushes:false,
    allow_deletions:false,
    required_conversation_resolution:true}')"

if [ "$DRY" -eq 1 ]; then
  echo "devloop protect: would protect $REPO branch $MAIN_BRANCH"
  printf '%s\n' "$PAYLOAD"
  exit 0
fi

printf '%s' "$PAYLOAD" | gh api -X PUT "repos/$REPO/branches/$MAIN_BRANCH/protection" --input - >/dev/null \
  || die "GitHub refused the protection update (admin? private repo? branch exists?)"

echo "devloop: protected $REPO/$MAIN_BRANCH"
gh api "repos/$REPO/branches/$MAIN_BRANCH/protection" \
  --jq '{required_checks:.required_status_checks.contexts, strict:.required_status_checks.strict, admins:.enforce_admins.enabled, force_push:.allow_force_pushes.enabled, deletions:.allow_deletions.enabled, reviews:(.required_pull_request_reviews.required_approving_review_count // 0)}'
echo "next: every change goes through --pr; direct pushes to $MAIN_BRANCH are rejected."
echo "bookkeeping (STATE/LESSONS): open a state/<sha> branch and merge it with gh pr merge."
