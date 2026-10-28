#!/usr/bin/env bash
# Merge the current task branch into MAIN_BRANCH, but only with fresh evidence.
#
# Refuses unless ALL hold:
#   1. current branch is not a protected branch;
#   2. a committed task file docs/tasks/<id>.md matches --task and the branch;
#   3. working tree is clean;
#   4. a passing, non-dirty gate result exists for HEAD;
#   5. an approving review for THIS task covers HEAD. The only commits allowed
#      after the reviewed SHA are additions under docs/reviews/; the review must
#      be created after the reviewed commit, and its blob is recorded;
#   6. contract files changed by the branch are explicitly approved by the review;
#   7. the diff stays within MAX_DIFF_LINES (unless --allow-oversized);
#   8. when REQUIRE_CI=true, GitHub check-runs are green for HEAD;
#   9. the merge result itself passes the gate before MAIN_BRANCH moves.
#
# Two integration modes:
#   local (default): merge in a detached worktree, gate it, move main, optionally --push;
#   --pr: push the branch, open/reuse a PR, wait for the required checks, merge via gh,
#         then gate the GitHub merge commit locally and sync main. REQUIRED when
#         REQUIRE_PR=true (branch protection makes direct pushes impossible anyway).
#
# Usage: integrate.sh --task <id> [--allow-oversized] [--dry-run] [--push|--pr]
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
need jq

TASK=""
ALLOW_OVERSIZED=0
DRY_RUN=0
PUSH=0
PR_MODE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --task) TASK="${2:-}"; shift 2 ;;
    --allow-oversized) ALLOW_OVERSIZED=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --push) PUSH=1; shift ;;
    --pr) PR_MODE=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$TASK" ] || die "usage: integrate.sh --task <id> [--allow-oversized] [--dry-run] [--push|--pr]"
[ "$PR_MODE" -eq 1 ] && [ "$PUSH" -eq 1 ] && die "--pr and --push are mutually exclusive"
if [ "$REQUIRE_PR" = "true" ] && [ "$PR_MODE" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
  die "REQUIRE_PR=true: direct main pushes are disabled; use --pr"
fi
if [ "$REQUIRE_PR" = "true" ] && [ "$PR_MODE" -eq 0 ] && [ "$DRY_RUN" -eq 1 ]; then
  echo "devloop: REQUIRE_PR=true, a real integration must use --pr" >&2
fi

BRANCH="$(current_branch)"
SHA="$(head_sha)"

# The defaults cannot be removed by a branch editing .devloop.conf.
for b in main master $PROTECTED_BRANCHES; do
  [ "$BRANCH" != "$b" ] || die "refusing to integrate from protected branch '$b'"
done

# --- serialize integrations ------------------------------------------------
mkdir -p "$ART"
TMPWT=""
LOCKDIR=""
cleanup() {
  if [ -n "$TMPWT" ]; then
    git worktree remove --force "$TMPWT" >/dev/null 2>&1 || true
    rm -rf "$TMPWT"
  fi
  if [ -n "$LOCKDIR" ]; then rmdir "$LOCKDIR" 2>/dev/null || true; fi
}
trap cleanup EXIT

if command -v flock >/dev/null 2>&1; then
  exec 9>"$ART/integrate.lock"
  flock -w "${LOCK_TIMEOUT:-900}" 9 || die "another integration holds the lock; retry later"
else
  LOCKDIR="$ART/integrate.lock.d"
  waited=0
  until mkdir "$LOCKDIR" 2>/dev/null; do
    waited=$((waited + 1))
    [ "$waited" -lt "${LOCK_TIMEOUT:-900}" ] || die "another integration holds $LOCKDIR; retry later"
    sleep 1
  done
fi

BASE="$(merge_base)"
is_dirty && die "working tree is dirty; commit or stash before integrating"

# --- task contract ---------------------------------------------------------
TASKFILE="docs/tasks/$TASK.md"
git cat-file -e "HEAD:$TASKFILE" 2>/dev/null || die "task file $TASKFILE is not committed at HEAD; write and commit it first"
[ "$(fm "$TASKFILE" id)" = "$TASK" ] || die "task file $TASKFILE does not declare id: $TASK"
TASK_BRANCH="$(fm "$TASKFILE" branch)"
[ -z "$TASK_BRANCH" ] || [ "$TASK_BRANCH" = "$BRANCH" ] || die "task branch '$TASK_BRANCH' does not match '$BRANCH'"
TASK_STATUS="$(fm "$TASKFILE" status)"
case "$TASK_STATUS" in
  review|done) ;;
  *) die "task status is '${TASK_STATUS:-unset}'; set status: review before integrating" ;;
esac
IMPLEMENTER="$(fm "$TASKFILE" implementer)"

# --- gate evidence ---------------------------------------------------------
GATE="$ART/gate/$SHA/result.json"
[ -f "$GATE" ] || die "no gate result for $SHA; run scripts/devloop/gate.sh"
[ "$(jq -r .ok "$GATE")" = "true" ] || die "gate failed for $SHA; see $GATE"
[ "$(jq -r .dirty "$GATE")" = "false" ] || die "gate ran on a dirty tree; commit and re-run gate.sh"
[ "$(jq -r .sha "$GATE")" = "$SHA" ] || die "gate result does not name HEAD"

# --- review evidence -------------------------------------------------------
REVIEW_FILE=""
REVIEWED_SHA=""
REVIEW_BLOB=""
REVIEW_CONTRACT=""
REVIEWER=""
APPROVED_BY=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ "$(fm "$f" task)" = "$TASK" ] || continue
  [ "$(fm "$f" verdict)" = "approve" ] || continue
  [ "$(fm "$f" blockers)" = "0" ] || continue
  v_sha="$(fm "$f" sha)"
  case "$v_sha" in *[!0-9a-f]*) continue ;; esac
  [ "${#v_sha}" -eq 40 ] || continue
  reviewer="$(fm "$f" reviewer)"
  [ -n "$reviewer" ] || continue
  git cat-file -e "${v_sha}^{commit}" 2>/dev/null || continue
  git cat-file -e "HEAD:$f" 2>/dev/null || continue
  # A review must be created after the commit it reviews: an edited review is
  # not immutability, and a review committed with the code proves nothing.
  git cat-file -e "$v_sha:$f" 2>/dev/null && continue
  [ "$v_sha" = "$SHA" ] && continue
  git merge-base --is-ancestor "$v_sha" "$SHA" 2>/dev/null || continue
  post="$(git diff --name-status "$v_sha..$SHA")"
  offenders="$(printf '%s\n' "$post" | grep -vE '^A[[:space:]]+docs/reviews/' || true)"
  [ -z "$offenders" ] || continue
  if [ "$reviewer" = "self" ]; then
    [ -n "$(fm "$f" approved_by)" ] || continue
  elif [ -n "$IMPLEMENTER" ] && [ "$reviewer" = "$IMPLEMENTER" ]; then
    continue
  fi
  REVIEW_FILE="$f"
  REVIEWED_SHA="$v_sha"
  REVIEW_BLOB="$(git rev-parse "HEAD:$f")"
  REVIEW_CONTRACT="$(fm "$f" contract)"
  REVIEWER="$reviewer"
  APPROVED_BY="$(fm "$f" approved_by)"
  break
done < <(git ls-files 'docs/reviews/*.md' | sort -r)
[ -n "$REVIEW_FILE" ] || die "no approving review for HEAD $SHA and task $TASK; run the code-review step"

if [ "$REVIEWED_SHA" != "$SHA" ]; then
  echo "devloop: review covers $REVIEWED_SHA; later commits only add docs/reviews/ (allowed)"
fi

# --- contract paths and size ----------------------------------------------
[ -n "$CONTRACT_PATHS" ] || die "CONTRACT_PATHS resolved empty; refusing to skip the contract check"
check_contract_and_size() {
  CHANGED="$(git diff --name-only "$BASE..$SHA")"
  TOUCHED=""
  for p in $CONTRACT_PATHS; do
    if printf '%s\n' "$CHANGED" | grep -qE "^${p}(/|$)"; then TOUCHED="${TOUCHED:+$TOUCHED }$p"; fi
  done
  if [ -n "$TOUCHED" ] && [ "$REVIEW_CONTRACT" != "approved" ]; then
    die "this change touches contract paths: $TOUCHED; the review must declare 'contract: approved'"
  fi
  LINES="$(diff_lines "$BASE")"
  if [ "$LINES" -gt "$MAX_DIFF_LINES" ] && [ "$ALLOW_OVERSIZED" -eq 0 ]; then
    die "diff is $LINES lines, above MAX_DIFF_LINES=$MAX_DIFF_LINES; split the task or pass --allow-oversized"
  fi
}
check_contract_and_size

# --- CI (optional, needs an authenticated gh + a remote) -------------------
if [ "$REQUIRE_CI" = "true" ] && [ "$PR_MODE" -eq 0 ]; then
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
echo "  task:   $TASK ($TASKFILE, status $TASK_STATUS)"
echo "  gate:   ${GATE#"$ROOT"/}"
echo "  review: $REVIEW_FILE (covers $REVIEWED_SHA, blob ${REVIEW_BLOB:0:12})"
if [ -n "$TOUCHED" ]; then echo "  contract: approved for $TOUCHED"; fi
echo "  diff:   $LINES lines (limit $MAX_DIFF_LINES)"

if [ "$DRY_RUN" -eq 1 ]; then
  if [ "$PR_MODE" -eq 1 ]; then
    echo "devloop: dry run, would push $BRANCH, open/reuse a PR, wait for checks, merge via gh, then gate the merge commit"
  else
    echo "devloop: dry run, nothing merged"
  fi
  exit 0
fi

# --- PR mode: GitHub is the arbiter ---------------------------------------
if [ "$PR_MODE" -eq 1 ]; then
  command -v gh >/dev/null 2>&1 || die "--pr requires gh"
  gh auth status >/dev/null 2>&1 || die "--pr requires an authenticated gh"
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)" || die "cannot resolve GitHub repo"

  # The owner may have merged the pull request from the GitHub UI. Re-running
  # this command then rebuilds the record from verifiable evidence instead of
  # opening a second pull request.
  MERGED_JSON="$(gh pr list --head "$BRANCH" --base "$MAIN_BRANCH" --state merged --limit 1 \
    --json number,url,mergeCommit,reviewDecision,headRefOid --jq '.[0] // empty' 2>/dev/null)" \
    || die "cannot query merged pull requests; check gh auth and network"
  if [ -n "$MERGED_JSON" ]; then
    MERGE_SHA="$(printf '%s' "$MERGED_JSON" | jq -r '.mergeCommit.oid // empty')"
    PR_NUM="$(printf '%s' "$MERGED_JSON" | jq -r '.number // empty')"
    PR_URL="$(printf '%s' "$MERGED_JSON" | jq -r '.url // empty')"
    MERGED_HEAD="$(printf '%s' "$MERGED_JSON" | jq -r '.headRefOid // empty')"
    MERGED_DECISION="$(printf '%s' "$MERGED_JSON" | jq -r '.reviewDecision // ""')"
    [ -n "$MERGE_SHA" ] || die "merged PR #$PR_NUM reports no merge commit"
    [ "$MERGED_HEAD" = "$SHA" ] \
      || die "branch moved after the merge: PR head $MERGED_HEAD, local HEAD $SHA"
    case "$MERGED_DECISION" in
      APPROVED|"") ;;
      *) die "merged PR #$PR_NUM has review state '$MERGED_DECISION'; refusing to record it" ;;
    esac
    echo "devloop: PR #$PR_NUM was merged by the owner; recording its evidence"
    git fetch -q origin "$MAIN_BRANCH" || die "cannot fetch origin/$MAIN_BRANCH"
    git merge-base --is-ancestor "$MERGE_SHA" "origin/$MAIN_BRANCH" \
      || die "merge commit $MERGE_SHA is not on origin/$MAIN_BRANCH; refusing to record it"
    [ "$(git rev-list --parents -n 1 "$MERGE_SHA" | wc -w | tr -d ' ')" -eq 3 ] \
      || die "$MERGE_SHA is not a two-parent merge commit; refusing to record it"
    BASE="$(git rev-parse "$MERGE_SHA^1")"
    check_contract_and_size
  else
    git push -u origin "$BRANCH" || die "cannot push $BRANCH to origin"
    PR_NUM="$(gh pr list --head "$BRANCH" --base "$MAIN_BRANCH" --state open --json number --jq '.[0].number // empty')"
    if [ -z "$PR_NUM" ]; then
      PR_BODY="$(printf 'Task: %s\nReviewed-by: %s\nReviewed-blob: %s\nGate: %s\n' \
        "$TASK" "$REVIEW_FILE" "$REVIEW_BLOB" "$SHA")"
      PR_URL="$(gh pr create --base "$MAIN_BRANCH" --head "$BRANCH" \
        --title "chore(merge): integrate $TASK ($BRANCH)" --body "$PR_BODY")" \
        || die "cannot create the pull request"
      PR_NUM="$(gh pr view "$PR_URL" --json number -q .number)" || die "cannot read the pull request number"
    else
      PR_URL="$(gh pr view "$PR_NUM" --json url -q .url)"
    fi

    # Check runs are created asynchronously after the PR event: wait for the
    # suite to register instead of racing it and merging without CI.
    CHECKS_READY=0
    for _ in $(seq 1 24); do
      CHECKS="$(gh pr checks "$PR_NUM" --json name 2>/dev/null || true)"
      if [ -n "$CHECKS" ] && [ "$CHECKS" != "[]" ]; then CHECKS_READY=1; break; fi
      sleep 5
    done
    [ "$CHECKS_READY" -eq 1 ] \
      || die "no CI checks appeared on the PR after 2 minutes; enable the workflow before using --pr"
    echo "devloop: waiting for the required checks on PR #$PR_NUM ($PR_URL)"
    timeout "${CI_WAIT_SECONDS:-1800}" gh pr checks "$PR_NUM" --watch --fail-fast \
      || die "PR checks failed or timed out; the PR was not merged"

    # Branch protection may require an owner/reviewer approval. Do not let
    # gh pr merge fail with a generic error: say exactly what is missing.
    DECISION="$(gh pr view "$PR_NUM" --json reviewDecision --jq '.reviewDecision // ""' 2>/dev/null || true)"
    case "$DECISION" in
      APPROVED|"") ;;
      REVIEW_REQUIRED)
        die "PR #$PR_NUM needs an approving review; approve it, then re-run --pr" ;;
      CHANGES_REQUESTED)
        die "PR #$PR_NUM has requested changes; address them and re-run --pr" ;;
      *)
        die "PR #$PR_NUM has review state '$DECISION'; approve it, then re-run --pr" ;;
    esac

    gh pr merge "$PR_NUM" --merge \
      || die "gh pr merge failed (required checks, protection, or conflict)"
    git push origin --delete "$BRANCH" >/dev/null 2>&1 || true
    MERGE_SHA="$(gh pr view "$PR_NUM" --json mergeCommit --jq '.mergeCommit.oid')" \
      || die "cannot read the merge commit"
    [ -n "$MERGE_SHA" ] || die "GitHub did not report a merge commit"
  fi

  git fetch -q origin "$MAIN_BRANCH" || die "cannot fetch origin/$MAIN_BRANCH"
  MAIN_REF="refs/heads/$MAIN_BRANCH"
  MAIN_SHA="$(git rev-parse "$MAIN_REF")"
  MAIN_WT="$(git worktree list --porcelain | awk -v ref="$MAIN_REF" '
    BEGIN { RS=""; FS="\n" }
    { wt=""; br=""; for (i=1;i<=NF;i++) { if ($i ~ /^worktree /) wt=substr($i,10); if ($i ~ /^branch /) br=substr($i,8) } if (br==ref) { print wt; exit } }')"
  TMPWT="$(mktemp -d "${TMPDIR:-/tmp}/devloop-merge.XXXXXX")" || die "cannot create a temporary directory"
  git worktree add -q --detach "$TMPWT" "$MERGE_SHA" || die "cannot check out the merge commit $MERGE_SHA"
  echo "devloop: gating the GitHub merge commit $MERGE_SHA"
  ( cd "$TMPWT" && bash "$ROOT/scripts/devloop/gate.sh" --task "$TASK" --quiet ) \
    || die "the GitHub merge commit failed the gate; main already contains it, investigate immediately"
  MGATE="$ART/gate/$MERGE_SHA/result.json"
  [ -f "$MGATE" ] || die "merge gate result missing for $MERGE_SHA"

  if [ -n "$MAIN_WT" ]; then
    [ -z "$(git -C "$MAIN_WT" status --porcelain)" ] || die "$MAIN_BRANCH is dirty at $MAIN_WT"
    git -C "$MAIN_WT" merge --ff-only "origin/$MAIN_BRANCH" >/dev/null \
      || die "cannot fast-forward $MAIN_BRANCH at $MAIN_WT to origin/$MAIN_BRANCH"
  else
    git update-ref -m "integrate $TASK (pr #$PR_NUM)" "$MAIN_REF" "origin/$MAIN_BRANCH" "$MAIN_SHA"
  fi

  mkdir -p "$ART/integrations"
  jq -n --arg task "$TASK" --arg branch "$BRANCH" --arg reviewed "$REVIEWED_SHA" \
    --arg head "$SHA" --arg merge "$MERGE_SHA" --arg review "$REVIEW_FILE" \
    --arg review_blob "$REVIEW_BLOB" --arg gate "$GATE" --arg merge_gate "$MGATE" \
    --arg contract "$TOUCHED" --arg reviewer "$REVIEWER" --arg pr "$PR_NUM" --arg pr_url "$PR_URL" \
    --arg base "$BASE" --argjson lines "$LINES" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{mode:"pr",task:$task,branch:$branch,reviewed_sha:$reviewed,head_sha:$head,merge_sha:$merge,
      review:$review,review_blob:$review_blob,gate:$gate,merge_gate:$merge_gate,contract_paths:$contract,
      reviewer:$reviewer,pr:$pr,pr_url:$pr_url,base:$base,diff_lines:$lines,pushed:true,integrated_at:$ts}' \
    > "$ART/integrations/$MERGE_SHA.json"

  echo "devloop: merged PR #$PR_NUM into $MAIN_BRANCH at $MERGE_SHA"
  echo "  reviewed: $REVIEWED_SHA ($REVIEW_FILE)"
  echo "  merge gate: ${MGATE#"$ROOT"/}"
  echo "next: update docs/STATE.md (last_verified_sha: $MERGE_SHA), then run scripts/devloop/doctor.sh"
  exit 0
fi

# --- merge in a detached worktree, gate it, then move main -----------------
MAIN_REF="refs/heads/$MAIN_BRANCH"
git rev-parse --verify --quiet "$MAIN_REF" >/dev/null || die "branch $MAIN_BRANCH does not exist"
MAIN_SHA="$(git rev-parse "$MAIN_REF")"
MAIN_WT="$(git worktree list --porcelain | awk -v ref="$MAIN_REF" '
  BEGIN { RS=""; FS="\n" }
  { wt=""; br=""; for (i=1;i<=NF;i++) { if ($i ~ /^worktree /) wt=substr($i,10); if ($i ~ /^branch /) br=substr($i,8) } if (br==ref) { print wt; exit } }')"
if [ -n "$MAIN_WT" ] && [ -n "$(git -C "$MAIN_WT" status --porcelain)" ]; then
  die "$MAIN_BRANCH is checked out at $MAIN_WT with uncommitted changes; clean it first"
fi

TMPWT="$(mktemp -d "${TMPDIR:-/tmp}/devloop-merge.XXXXXX")" || die "cannot create a temporary directory"
git worktree add -q --detach "$TMPWT" "$MAIN_BRANCH" || die "cannot create a merge worktree"
if ! ( cd "$TMPWT" && git merge --no-ff "$BRANCH" \
    -m "chore(merge): integrate $TASK ($BRANCH)" \
    -m "Task: $TASK" \
    -m "Reviewed-by: $REVIEW_FILE" \
    -m "Reviewed-blob: $REVIEW_BLOB" \
    -m "Gate: $SHA" ); then
  die "merge conflict or failure; rebase $BRANCH on $MAIN_BRANCH, re-run the gate and retry"
fi
MERGE_SHA="$(git -C "$TMPWT" rev-parse HEAD)"
[ "$MERGE_SHA" != "$MAIN_SHA" ] || die "nothing to merge: $BRANCH is already contained in $MAIN_BRANCH"

echo "devloop: gating the merge result $MERGE_SHA (the commit that will land on $MAIN_BRANCH)"
( cd "$TMPWT" && bash "$ROOT/scripts/devloop/gate.sh" --task "$TASK" --quiet ) \
  || die "the merge result failed the gate; $MAIN_BRANCH was not updated"
MGATE="$ART/gate/$MERGE_SHA/result.json"
[ -f "$MGATE" ] || die "merge gate result missing for $MERGE_SHA"
[ "$(jq -r .ok "$MGATE")" = "true" ] || die "merge gate failed for $MERGE_SHA"
[ "$(jq -r .dirty "$MGATE")" = "false" ] || die "merge gate was produced on a dirty tree for $MERGE_SHA"

if [ -n "$MAIN_WT" ]; then
  git -C "$MAIN_WT" merge --ff-only "$MERGE_SHA" >/dev/null \
    || die "cannot fast-forward $MAIN_BRANCH at $MAIN_WT to $MERGE_SHA"
else
  git update-ref -m "integrate $TASK" "$MAIN_REF" "$MERGE_SHA" "$MAIN_SHA"
fi

PUSHED=false
PUSH_FAILED=0
if [ "$PUSH" -eq 1 ]; then
  if git remote get-url origin >/dev/null 2>&1; then
    if ALLOW_MAIN_PUSH=1 git push origin "$MAIN_BRANCH"; then PUSHED=true
    else PUSH_FAILED=1; fi
  else
    PUSH_FAILED=1
  fi
fi

mkdir -p "$ART/integrations"
jq -n --arg task "$TASK" --arg branch "$BRANCH" --arg reviewed "$REVIEWED_SHA" \
  --arg head "$SHA" --arg merge "$MERGE_SHA" --arg review "$REVIEW_FILE" \
  --arg review_blob "$REVIEW_BLOB" --arg gate "$GATE" --arg merge_gate "$MGATE" \
  --arg contract "$TOUCHED" --arg reviewer "$REVIEWER" --arg approved_by "$APPROVED_BY" \
  --arg base "$BASE" --argjson lines "$LINES" --argjson pushed "$PUSHED" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{mode:"local",task:$task,branch:$branch,reviewed_sha:$reviewed,head_sha:$head,merge_sha:$merge,
    review:$review,review_blob:$review_blob,gate:$gate,merge_gate:$merge_gate,
    contract_paths:$contract,reviewer:$reviewer,approved_by:$approved_by,base:$base,
    diff_lines:$lines,pushed:$pushed,integrated_at:$ts}' \
  > "$ART/integrations/$MERGE_SHA.json"

echo "devloop: merged $BRANCH into $MAIN_BRANCH at $MERGE_SHA"
echo "  reviewed: $REVIEWED_SHA ($REVIEW_FILE)"
echo "  merge gate: ${MGATE#"$ROOT"/}"
if [ "$PUSHED" = true ]; then echo "  pushed: origin/$MAIN_BRANCH"; fi
echo "next: update docs/STATE.md (last_verified_sha: $MERGE_SHA), then run scripts/devloop/doctor.sh"

if [ "$PUSH_FAILED" -eq 1 ]; then
  die "--push was requested but the push failed; $MAIN_BRANCH is merged locally only"
fi
