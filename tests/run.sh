#!/usr/bin/env bash
# End-to-end tests for the devloop kit. Creates a throwaway repository, installs the kit,
# and checks that every refusal and every acceptance actually happens.
#
# Run: bash tests/run.sh
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
REPO="$TMP/repo"
PASS=0
FAIL=0

cleanup() { if [ "${KEEP_TMP:-0}" = "1" ]; then echo "kept: $TMP"; else rm -rf "$TMP"; fi; }
trap cleanup EXIT

ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$*"; }
ko()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$*"; }
say() { printf '\n== %s\n' "$*"; }

expect_ok()   { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi; }
expect_fail() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ko "$d"; else ok "$d"; fi; }

setup() {
  mkdir -p "$REPO"
  cp -a "$SRC/AGENTS.md" "$SRC/.agents" "$SRC/scripts" "$SRC/.githooks" "$SRC/.github" \
        "$SRC/docs" "$REPO/"
  cd "$REPO" || exit 1
  git init -q -b main
  git config user.name "devloop test"
  git config user.email "devloop@example.invalid"
  chmod +x .githooks/* scripts/devloop/*.sh

  cat > .devloop.conf <<'EOF'
CHECK_TEST="node --test"
CHECK_LINT="node --check src/math.js"
MAIN_BRANCH="main"
MAX_DIFF_LINES="400"
EOF

  cat > package.json <<'EOF'
{"name":"devloop-fixture","type":"module","private":true}
EOF
  mkdir -p src test
  cat > src/math.js <<'EOF'
export function add(a, b) {
  return a + b;
}
EOF
  cat > test/math.test.js <<'EOF'
import { test } from "node:test";
import assert from "node:assert/strict";
import { add } from "../src/math.js";

test("adds two numbers", () => {
  assert.equal(add(2, 3), 5);
});
EOF

  bash scripts/devloop/install-hooks.sh >/dev/null
  git add -A
  git commit -q -m "chore: bootstrap fixture"
  ART_DIR="$(git rev-parse --path-format=absolute --git-common-dir)/devloop"
}

new_branch() { git switch -q -c "$1" main; }

write_review() { # <file> <sha> <verdict> <blockers>
  mkdir -p docs/reviews
  cat > "$1" <<EOF
---
task: task-001
sha: $2
verdict: $3
blockers: $4
reviewer: test-harness
date: 2026-10-21
---

## Evidence

| Rubric item | Evidence |
|---|---|
| Acceptance | fixture |
| Tests | fixture |
EOF
  git add "$1"
  git commit -q -m "docs(reviews): record verdict $(basename "$1" .md)"
}

setup
say "artifact store"

expect_ok "first gate run" bash scripts/devloop/gate.sh --quiet
expect_ok "second gate run" bash scripts/devloop/gate.sh --quiet
ART_SHA="$(git rev-parse HEAD)"
[ -f "$ART_DIR/gate/$ART_SHA/result.json" ] \
  && ok "artifacts live in the git common dir" || ko "artifacts live in the git common dir"
[ ! -e .devloop ] \
  && ok "no artifact directory inside the worktree" || ko "no artifact directory inside the worktree"
[ -z "$(git status --porcelain)" ] \
  && ok "gate output does not dirty the tree" || ko "gate output does not dirty the tree"
[ "$(jq -r .dirty "$ART_DIR/gate/$ART_SHA/result.json")" = "false" ] \
  && ok "second run records dirty=false" || ko "second run records dirty=false"
WT_ART="$TMP/wt-artifacts"
git worktree add -q --detach "$WT_ART" main
( cd "$WT_ART" \
  && [ -f "$(git rev-parse --path-format=absolute --git-common-dir)/devloop/gate/$ART_SHA/result.json" ] ) \
  && ok "linked worktree sees the same artifacts" || ko "linked worktree sees the same artifacts"
git worktree remove --force "$WT_ART" >/dev/null 2>&1

say "hooks and commit policy"

printf '// touch\n' >> src/math.js
git add -A
expect_fail "commit-msg rejects a non-conventional subject" git commit -q -m "bad message"
git reset -q --hard HEAD
git clean -qfd

git switch -q -c task/001-multiply
cat >> src/math.js <<'EOF'

export function multiply(a, b) {
  return a * b;
}
EOF
cat > test/multiply.test.js <<'EOF'
import { test } from "node:test";
import assert from "node:assert/strict";
import { multiply } from "../src/math.js";

test("multiplies two numbers", () => {
  assert.equal(multiply(3, 4), 12);
});
EOF
git add -A
expect_ok "commit-msg accepts a conventional subject" git commit -q -m "feat(math): add multiply"

say "gate"
expect_ok "gate passes on green code" bash scripts/devloop/gate.sh --quiet
SHA1="$(git rev-parse HEAD)"
[ "$(jq -r .ok "$ART_DIR/gate/$SHA1/result.json")" = "true" ] \
  && ok "gate result records ok=true" || ko "gate result records ok=true"
[ "$(jq -r .sha "$ART_DIR/gate/$SHA1/result.json")" = "$SHA1" ] \
  && ok "gate result is bound to HEAD" || ko "gate result is bound to HEAD"
[ "$(jq -r .dirty "$ART_DIR/gate/$SHA1/result.json")" = "false" ] \
  && ok "clean tree recorded as dirty=false" || ko "clean tree recorded as dirty=false"

TMP_CONF="$TMP/function.conf"
cp .devloop.conf "$TMP_CONF"
printf '\nshell_fn_check() { return 0; }\nCHECK_FUNCTION="shell_fn_check"\n' >> "$TMP_CONF"
expect_ok "gate evaluates shell functions from the configuration" \
  env DEVLOOP_CONF="$TMP_CONF" bash scripts/devloop/gate.sh --quiet
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1

say "dirty gate"
printf '// dirty\n' >> src/math.js
D_OUT="$(bash scripts/devloop/gate.sh 2>&1)"; D_CODE=$?
[ "$D_CODE" -eq 3 ] && ok "dirty gate exits 3" || ko "dirty gate exits 3 (got $D_CODE)"
case "$D_OUT" in
  *PASSED*) ko "dirty gate never prints PASSED" ;;
  *) ok "dirty gate never prints PASSED" ;;
esac
git checkout -q -- src/math.js
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1

say "review packet"
PACKET="$(bash scripts/devloop/packet.sh)"
[ -f "$PACKET" ] && ok "packet file created" || ko "packet file created"
grep -q '^## Diff' "$PACKET" && ok "packet contains a diff section" || ko "packet contains a diff section"

say "integration refusals"
expect_fail "integrate refuses without a review" bash scripts/devloop/integrate.sh --task task-001
OUT="$(bash scripts/devloop/integrate.sh --task task-001 2>&1 || true)"
printf '%s' "$OUT" | grep -q "no approving review" \
  && ok "refusal names the missing review" || ko "refusal names the missing review"

WRONG="$(printf '0%.0s' $(seq 1 40))"
write_review docs/reviews/task-001-r1.md "$WRONG" approve 0
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
expect_fail "integrate refuses a review for an unknown SHA" bash scripts/devloop/integrate.sh --task task-001

say "happy path"
HEAD_NOW="$(git rev-parse HEAD)"
write_review docs/reviews/task-001-r2.md "$HEAD_NOW" approve 0
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
expect_ok "integrate accepts clean gate + approving review" bash scripts/devloop/integrate.sh --task task-001
CONTENT="$(git show main:src/math.js)"
case "$CONTENT" in
  *multiply*) ok "merged commit contains the change" ;;
  *) ko "merged commit contains the change" ;;
esac
MERGED_SHA="$(git rev-parse HEAD)"
LOG="$(git log --oneline main)"
case "$LOG" in
  *"chore(merge)"*) ok "merge commit uses the conventional subject" ;;
  *) ko "merge commit uses the conventional subject" ;;
esac
[ -f "$ART_DIR/integrations/$MERGED_SHA.json" ] \
  && ok "integration audit record created" || ko "integration audit record created"

say "doctor"
expect_ok "doctor accepts main after an integration" bash scripts/devloop/doctor.sh
D_OUT="$(bash scripts/devloop/doctor.sh 2>&1)"; D_CODE=$?
[ "$D_CODE" -eq 0 ] && ok "doctor exits 0 on the integrated main" || ko "doctor exits 0 on the integrated main"
case "$D_OUT" in
  *"shared artifact store"*) ok "doctor recognizes the shared artifact store" ;;
  *) ko "doctor recognizes the shared artifact store" ;;
esac
case "$D_OUT" in
  *"inside the worktree"*) ko "doctor does not misreport the shared store" ;;
  *) ok "doctor does not misreport the shared store" ;;
esac

say "merge gate evidence"
MERGE_SHA="$(git rev-parse main)"
MGATE="$ART_DIR/gate/$MERGE_SHA/result.json"
mkdir -p "$(dirname "$MGATE")"
jq -n --arg sha "$MERGE_SHA" '{sha:$sha,ok:true,dirty:false,checks:[]}' > "$MGATE"
REC="$ART_DIR/integrations/$MERGE_SHA.json"
jq --arg mg "$MGATE" '.merge_gate=$mg' "$REC" > "$REC.tmp" && mv "$REC.tmp" "$REC"
D_OUT="$(bash scripts/devloop/doctor.sh 2>&1)"
printf '%s' "$D_OUT" | grep -q "merge commit has a passing clean gate result" \
  && ok "doctor reads merge gate evidence" || ko "doctor reads merge gate evidence"
jq 'del(.merge_gate)' "$REC" > "$REC.tmp" && mv "$REC.tmp" "$REC"
rm -rf "$ART_DIR/gate/$MERGE_SHA"

say "legacy artifact store"
LEGACY="$REPO/.devloop/artifacts"
mkdir -p "$LEGACY"
cp -a "$ART_DIR/." "$LEGACY/"
rm -rf "$ART_DIR"
D_OUT="$(bash scripts/devloop/doctor.sh 2>&1)"; D_CODE=$?
if [ "$D_CODE" -eq 0 ]; then ok "doctor accepts a legacy artifact store"
else ko "doctor accepts a legacy artifact store"; printf '%s\n' "$D_OUT" | sed 's/^/    /'; fi
case "$D_OUT" in
  *"legacy store"*) ok "doctor names the legacy store" ;;
  *) ko "doctor names the legacy store" ;;
esac
rm -rf "$LEGACY"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1

say "gate failures"
git switch -q main
new_branch task/002-break
sed -i 's/return a + b;/return a - b;/' src/math.js
git commit -qam "fix(math): change add semantics"
expect_fail "gate fails when a check fails" bash scripts/devloop/gate.sh --quiet
[ "$(jq -r .ok "$ART_DIR/gate/$(git rev-parse HEAD)/result.json")" = "false" ] \
  && ok "failed gate records ok=false" || ko "failed gate records ok=false"
git switch -q main

say "dirty tree"
new_branch task/003-dirty
printf '// uncommitted\n' >> src/math.js
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
DSHA="$(git rev-parse HEAD)"
[ "$(jq -r .dirty "$ART_DIR/gate/$DSHA/result.json")" = "true" ] \
  && ok "gate records dirty=true for uncommitted work" || ko "gate records dirty=true for uncommitted work"
expect_fail "integrate refuses a dirty-tree gate" bash scripts/devloop/integrate.sh --task task-003
git restore .
git switch -q main

say "size accounting"
git switch -q main
new_branch task/004-size
printf '// size probe\n' >> src/math.js
git commit -qam "chore(math): probe the size accounting"
mkdir -p docs/reviews
printf '# padding verdict\n' > docs/reviews/padding-r1.md
for i in $(seq 1 40); do printf -- '- evidence line %s\n' "$i" >> docs/reviews/padding-r1.md; done
git add -A
git commit -q -m "docs(reviews): add size probe evidence"
BASE_SIZE="$(git merge-base main HEAD)"
RAW_SIZE="$(git diff --numstat "$BASE_SIZE..HEAD" | awk '{a+=$1;d+=$2} END{print a+d}')"
CODE_SIZE="$(bash -c '. ./scripts/devloop/common.sh; diff_lines "$1"' _ "$BASE_SIZE")"
[ "$CODE_SIZE" -lt "$RAW_SIZE" ] \
  && ok "size accounting ignores review evidence" || ko "size accounting ignores review evidence"
git switch -q main

say "size limit"
new_branch task/004-big
node -e 'let s=""; for (let i=0;i<450;i++) s += `export const v${i} = ${i};\n`; process.stdout.write(s)' > src/big.js
git add -A
git commit -q -m "feat(big): add generated constants"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
BIG_SHA="$(git rev-parse HEAD)"
write_review docs/reviews/task-004-r1.md "$BIG_SHA" approve 0
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
OUT="$(bash scripts/devloop/integrate.sh --task task-004 2>&1 || true)"
printf '%s' "$OUT" | grep -q "MAX_DIFF_LINES" \
  && ok "integrate refuses an oversized diff" || ko "integrate refuses an oversized diff"
git switch -q main

say "review freshness"
new_branch task/005-late
printf '\nexport const late = 1;\n' >> src/math.js
git commit -qam "feat(math): add late constant"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
R5="$(git rev-parse HEAD)"
write_review docs/reviews/task-005-r1.md "$R5" approve 0
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
printf '\nexport const later = 2;\n' >> src/math.js
git commit -qam "feat(math): add later constant"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
expect_fail "code committed after review invalidates the approval" bash scripts/devloop/integrate.sh --task task-005
git switch -q main

say "policy"
new_branch task/006-policy
printf '\nexport const p = 1;\n' >> src/math.js
git add -A
git commit -q --no-verify -m "bad message"
expect_fail "policy catches a non-conventional commit that bypassed the hook" \
  bash scripts/devloop/policy.sh main
OUT="$(bash scripts/devloop/policy.sh main 2>&1 || true)"
printf '%s' "$OUT" | grep -q "VIOLATION commit subject" \
  && ok "policy names the offending subject" || ko "policy names the offending subject"
git switch -q main

say "pre-push protection"
git init -q --bare "$TMP/remote.git"
git remote add origin "$TMP/remote.git"
expect_fail "pre-push blocks a direct push to main" git push -q origin main
expect_ok "ALLOW_MAIN_PUSH=1 overrides deliberately" env ALLOW_MAIN_PUSH=1 git push -q origin main
new_branch task/007-push
printf '\nexport const pushed = 1;\n' >> src/math.js
git commit -qam "chore(math): touch for push test"
expect_ok "pre-push allows a task branch" git push -q origin task/007-push
git reset -q --hard HEAD~1
expect_fail "pre-push blocks a non-fast-forward push" git push -q --force origin task/007-push
git switch -q main

say "doctor without evidence"
new_branch task/008-nogate
printf '\nexport const n = 0;\n' >> src/math.js
git commit -qam "chore(math): add n"
expect_fail "doctor flags a commit with no gate or review" bash scripts/devloop/doctor.sh
git switch -q main

say "results"
printf 'passed: %d, failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
