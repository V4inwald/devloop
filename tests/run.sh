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
[ "$(jq -r .ok ".devloop/artifacts/gate/$SHA1/result.json")" = "true" ] \
  && ok "gate result records ok=true" || ko "gate result records ok=true"
[ "$(jq -r .sha ".devloop/artifacts/gate/$SHA1/result.json")" = "$SHA1" ] \
  && ok "gate result is bound to HEAD" || ko "gate result is bound to HEAD"
[ "$(jq -r .dirty ".devloop/artifacts/gate/$SHA1/result.json")" = "false" ] \
  && ok "clean tree recorded as dirty=false" || ko "clean tree recorded as dirty=false"

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
[ -f ".devloop/artifacts/integrations/$MERGED_SHA.json" ] \
  && ok "integration audit record created" || ko "integration audit record created"

say "doctor"
expect_ok "doctor accepts main after an integration" bash scripts/devloop/doctor.sh

say "gate failures"
git switch -q main
new_branch task/002-break
sed -i 's/return a + b;/return a - b;/' src/math.js
git commit -qam "fix(math): change add semantics"
expect_fail "gate fails when a check fails" bash scripts/devloop/gate.sh --quiet
[ "$(jq -r .ok ".devloop/artifacts/gate/$(git rev-parse HEAD)/result.json")" = "false" ] \
  && ok "failed gate records ok=false" || ko "failed gate records ok=false"
git switch -q main

say "dirty tree"
new_branch task/003-dirty
printf '// uncommitted\n' >> src/math.js
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
DSHA="$(git rev-parse HEAD)"
[ "$(jq -r .dirty ".devloop/artifacts/gate/$DSHA/result.json")" = "true" ] \
  && ok "gate records dirty=true for uncommitted work" || ko "gate records dirty=true for uncommitted work"
expect_fail "integrate refuses a dirty-tree gate" bash scripts/devloop/integrate.sh --task task-003
git restore .
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
