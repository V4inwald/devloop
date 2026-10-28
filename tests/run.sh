#!/usr/bin/env bash
# End-to-end tests for the devloop kit. Creates a throwaway repository, installs the kit,
# and checks that every refusal and every acceptance actually happens.
#
# Run: bash tests/run.sh
set -uo pipefail

# The gate may be invoked from CI with a global artifact store. Fixtures are
# separate repositories and must use their own stores, otherwise every
# SHA-keyed assertion reads another repository's evidence.
unset DEVLOOP_ARTIFACTS DEVLOOP_CONF DEVLOOP_LEGACY_ARTIFACTS

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
  # The kit's own verdicts and task contracts are history, not fixture data:
  # keeping them would make the fixture's first review a modification.
  rm -f "$REPO"/docs/reviews/*.md "$REPO"/docs/tasks/task-*.md
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

# Start a task branch with a committed contract: integrate.sh refuses without one.
start_task() { # <id> <slug> [implementer]
  git switch -q main
  git switch -q -c "task/$2"
  mkdir -p docs/tasks
  cat > "docs/tasks/$1.md" <<EOF
---
id: $1
status: review
branch: task/$2
created: 2026-10-21
owner: test
implementer: ${3:-implementer-a}
---
# $1

## Acceptance criteria

- [ ] AC1: fixture
EOF
  git add "docs/tasks/$1.md"
  git commit -q -m "docs(tasks): add $1"
}

write_review() { # <file> <sha> <verdict> <blockers> [task] [reviewer] [extra]
  local task="${5:-task-001}" reviewer="${6:-test-harness}" extra="${7:-}"
  mkdir -p docs/reviews
  cat > "$1" <<EOF
---
task: $task
sha: $2
verdict: $3
blockers: $4
reviewer: $reviewer
contract: n/a
date: 2026-10-21
$extra
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

start_task task-001 001-multiply
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
write_review docs/reviews/task-001-r2.md "$HEAD_NOW" approve 0 task-001
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
expect_ok "integrate accepts clean gate + approving review" bash scripts/devloop/integrate.sh --task task-001
[ "$(git rev-parse --abbrev-ref HEAD)" = "task/001-multiply" ] \
  && ok "integration leaves the task branch checked out" || ko "integration leaves the task branch checked out"
CONTENT="$(git show main:src/math.js)"
case "$CONTENT" in
  *multiply*) ok "merged commit contains the change" ;;
  *) ko "merged commit contains the change" ;;
esac
MERGED_SHA="$(git rev-parse main)"
LOG="$(git log --oneline main)"
case "$LOG" in
  *"chore(merge)"*) ok "merge commit uses the conventional subject" ;;
  *) ko "merge commit uses the conventional subject" ;;
esac
[ -f "$ART_DIR/integrations/$MERGED_SHA.json" ] \
  && ok "integration audit record created" || ko "integration audit record created"
[ -f "$ART_DIR/gate/$MERGED_SHA/result.json" ] \
  && ok "merge commit has its own gate result" || ko "merge commit has its own gate result"
if jq -e '.ok == true and .dirty == false' "$ART_DIR/gate/$MERGED_SHA/result.json" >/dev/null 2>&1; then
  ok "merge gate passed on a clean tree"
else
  ko "merge gate passed on a clean tree"
fi
[ -n "$(jq -r '.merge_gate // empty' "$ART_DIR/integrations/$MERGED_SHA.json")" ] \
  && ok "integration record names the merge gate" || ko "integration record names the merge gate"
git log -1 --format=%B main | grep -q "Reviewed-blob:" \
  && ok "merge commit records the review blob" || ko "merge commit records the review blob"

git switch -q main
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
D_OUT="$(bash scripts/devloop/doctor.sh 2>&1)"
printf '%s' "$D_OUT" | grep -q "merge commit has a passing clean gate result" \
  && ok "doctor reads the merge gate produced by integrate" || ko "doctor reads the merge gate produced by integrate"

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
start_task task-004 004-big
node -e 'let s=""; for (let i=0;i<450;i++) s += `export const v${i} = ${i};\n`; process.stdout.write(s)' > src/big.js
git add -A
git commit -q -m "feat(big): add generated constants"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
BIG_SHA="$(git rev-parse HEAD)"
write_review docs/reviews/task-004-r1.md "$BIG_SHA" approve 0 task-004
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
OUT="$(bash scripts/devloop/integrate.sh --task task-004 2>&1 || true)"
printf '%s' "$OUT" | grep -q "MAX_DIFF_LINES" \
  && ok "integrate refuses an oversized diff" || ko "integrate refuses an oversized diff"
git switch -q main

say "review freshness"
start_task task-005 005-late
printf '\nexport const late = 1;\n' >> src/math.js
git commit -qam "feat(math): add late constant"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
R5="$(git rev-parse HEAD)"
write_review docs/reviews/task-005-r1.md "$R5" approve 0 task-005
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
printf '\nexport const later = 2;\n' >> src/math.js
git commit -qam "feat(math): add later constant"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
expect_fail "code committed after review invalidates the approval" bash scripts/devloop/integrate.sh --task task-005
git switch -q main

say "task contract"
start_task task-010 010-cross
printf 'export const ten = 10;\n' > src/ten.js
git add -A
git commit -q -m "feat(ten): add ten"
S10="$(git rev-parse HEAD)"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
write_review docs/reviews/task-999-r1.md "$S10" approve 0 task-999
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
expect_fail "integrate refuses a review for another task" bash scripts/devloop/integrate.sh --task task-010
git switch -q main

new_branch task/011-notask
printf 'export const eleven = 11;\n' > src/eleven.js
git add -A
git commit -q -m "feat(eleven): add eleven"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
expect_fail "integrate refuses a branch with no task file" bash scripts/devloop/integrate.sh --task task-011
git switch -q main

start_task task-012 012-self
printf 'export const twelve = 12;\n' > src/twelve.js
git add -A
git commit -q -m "feat(twelve): add twelve"
S12="$(git rev-parse HEAD)"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
write_review docs/reviews/task-012-r1.md "$S12" approve 0 task-012 self
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
expect_fail "integrate refuses an unapproved self review" bash scripts/devloop/integrate.sh --task task-012
write_review docs/reviews/task-012-r2.md "$S12" approve 0 task-012 self "approved_by: human"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
expect_ok "integrate accepts a self review with human approval" bash scripts/devloop/integrate.sh --task task-012
git switch -q main

start_task task-013 013-tamper
printf 'export const thirteen = 13;\n' > src/thirteen.js
git add -A
git commit -q -m "feat(thirteen): add thirteen"
S13="$(git rev-parse HEAD)"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
write_review docs/reviews/task-013-r1.md "$S13" approve 0 task-013
printf 'export const thirteen_b = 1;\n' > src/thirteen_b.js
git add -A
git commit -q -m "feat(thirteen): add a second file"
S13B="$(git rev-parse HEAD)"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
sed -i "s/^sha: .*/sha: $S13B/" docs/reviews/task-013-r1.md
git commit -q -am "docs(reviews): refresh task-013 verdict"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
expect_fail "integrate refuses a review rewritten after approval" bash scripts/devloop/integrate.sh --task task-013
git switch -q main

start_task task-014 014-contract
printf '\n# contract probe\n' >> scripts/devloop/common.sh
printf 'export const fourteen = 14;\n' > src/fourteen.js
git add -A
git commit -q -m "chore(devloop): touch the contract"
S14="$(git rev-parse HEAD)"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
write_review docs/reviews/task-014-r1.md "$S14" approve 0 task-014
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
OUT="$(bash scripts/devloop/integrate.sh --task task-014 2>&1 || true)"
printf '%s' "$OUT" | grep -q "contract paths" \
  && ok "integrate refuses a contract change without approval" || ko "integrate refuses a contract change without approval"
git switch -q main

start_task task-015 015-fm
printf 'export const fifteen = 15;\n' > src/fifteen.js
git add -A
git commit -q -m "feat(fifteen): add fifteen"
S15="$(git rev-parse HEAD)"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
mkdir -p docs/reviews
cat > docs/reviews/task-015-r1.md <<EOF
---
task: task-015
sha: $S15
verdict: approve
blockers: 0
reviewer: test-harness
date: 2026-10-21
---
## Evidence
| A | fixture |
EOF
git add docs/reviews
git commit -q -m "docs(reviews): approve task-015"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
expect_ok "integrate tolerates a review without a contract field" bash scripts/devloop/integrate.sh --task task-015
git switch -q main

start_task task-016 016-contract-empty
printf '\nCONTRACT_PATHS_DEFAULT=""\nCONTRACT_PATHS=""\n' >> .devloop.conf
printf '\n# contract probe 2\n' >> scripts/devloop/common.sh
printf 'export const sixteen = 16;\n' > src/sixteen.js
git add -A
git commit -q -m "chore(devloop): empty the contract paths"
S16="$(git rev-parse HEAD)"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
write_review docs/reviews/task-016-r1.md "$S16" approve 0 task-016
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
OUT="$(bash scripts/devloop/integrate.sh --task task-016 2>&1 || true)"
printf '%s' "$OUT" | grep -q "contract paths" \
  && ok "contract defaults cannot be disabled by the branch" || ko "contract defaults cannot be disabled by the branch"
git switch -q main

say "worktree integration"
git switch -q -c scratch/wt-base main
WT_MAIN="$TMP/wt-main"
WT_TASK="$TMP/wt-task"
git worktree add -q "$WT_MAIN" main
git worktree add -q -b task/020-wt "$WT_TASK" main
(
  cd "$WT_TASK" || exit 1
  mkdir -p docs/tasks
  cat > docs/tasks/task-020.md <<'EOF'
---
id: task-020
status: review
branch: task/020-wt
created: 2026-10-21
owner: test
implementer: implementer-a
---
# task-020
EOF
  git add docs/tasks/task-020.md
  git commit -q -m "docs(tasks): add task-020"
  printf 'export const twenty = 20;\n' > src/twenty.js
  git add -A
  git commit -q -m "feat(twenty): add twenty"
  S20="$(git rev-parse HEAD)"
  bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
  write_review docs/reviews/task-020-r1.md "$S20" approve 0 task-020
  bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
  bash scripts/devloop/integrate.sh --task task-020 >/dev/null 2>&1
  if [ "$(git rev-parse --abbrev-ref HEAD)" = "task/020-wt" ]; then echo "WT_BRANCH_OK"; else echo "WT_BRANCH_BAD"; fi
) > "$TMP/wt.out" 2>&1
grep -q WT_BRANCH_OK "$TMP/wt.out" \
  && ok "worktree integration leaves the caller on its branch" || ko "worktree integration leaves the caller on its branch"
[ "$(git -C "$WT_MAIN" rev-parse HEAD)" = "$(git rev-parse main)" ] \
  && ok "main worktree fast-forwarded to the merge commit" || ko "main worktree fast-forwarded to the merge commit"
[ -f "$ART_DIR/gate/$(git rev-parse main)/result.json" ] \
  && ok "worktree merge result is gated" || ko "worktree merge result is gated"
git worktree remove --force "$WT_TASK" >/dev/null 2>&1
git worktree remove --force "$WT_MAIN" >/dev/null 2>&1
git switch -q main

say "bookkeeping doctor"
printf '\n<!-- bookkeeping probe -->\n' >> docs/STATE.md
printf '\n<!-- task bookkeeping probe -->\n' >> docs/tasks/task-001.md
git add docs/STATE.md docs/tasks/task-001.md
git commit -q -m "chore(state): probe bookkeeping evidence"
D_OUT="$(bash scripts/devloop/doctor.sh 2>&1)"; D_CODE=$?
if [ "$D_CODE" -eq 0 ]; then ok "doctor accepts STATE and task-status bookkeeping"
else ko "doctor accepts STATE and task-status bookkeeping"; printf '%s\n' "$D_OUT" | sed 's/^/    /'; fi
printf '%s' "$D_OUT" | grep -q "bookkeeping commit" \
  && ok "doctor names the bookkeeping commit" || ko "doctor names the bookkeeping commit"

say "merge gate failure"
git switch -q main
MAIN_BEFORE="$(git rev-parse main)"
git switch -q -c task/030-mergefail
mkdir -p docs/tasks
cat > docs/tasks/task-030.md <<'EOF'
---
id: task-030
status: review
branch: task/030-mergefail
created: 2026-10-21
owner: test
implementer: implementer-a
---
# task-030
EOF
git add docs/tasks/task-030.md
git commit -q -m "docs(tasks): add task-030"
printf 'export const thirty = 30;\n' > src/thirty.js
cat > test/thirty.test.js <<'EOF'
import { test } from "node:test";
import assert from "node:assert/strict";
import { add } from "../src/math.js";

test("the merged add contract", () => {
  assert.equal(add(2, 3), 5);
});
EOF
git add -A
git commit -q -m "feat(thirty): add thirty and pin add semantics"
S30="$(git rev-parse HEAD)"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
write_review docs/reviews/task-030-r1.md "$S30" approve 0 task-030
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
git switch -q main
sed -i 's/return a + b;/return a - b;/' src/math.js
git commit -qam "fix(math): change add semantics on main"
MAIN_AFTER="$(git rev-parse main)"
git switch -q task/030-mergefail
OUT="$(bash scripts/devloop/integrate.sh --task task-030 2>&1 || true)"
printf '%s' "$OUT" | grep -q "merge result failed the gate" \
  && ok "a failing merge gate is reported" || ko "a failing merge gate is reported"
[ "$(git rev-parse main)" = "$MAIN_AFTER" ] \
  && ok "a failing merge gate leaves main untouched" || ko "a failing merge gate leaves main untouched"
git switch -q main
git reset -q --hard "$MAIN_BEFORE"

say "bookkeeping fail-closed"
git switch -q -c task/031-ff
mkdir -p docs/tasks
cat > docs/tasks/task-031.md <<'EOF'
---
id: task-031
status: review
branch: task/031-ff
created: 2026-10-21
owner: test
implementer: implementer-a
---
# task-031
EOF
git add docs/tasks/task-031.md
git commit -q -m "docs(tasks): add task-031"
printf 'export const thirtyone = 31;\n' > src/thirtyone.js
git add -A
git commit -q -m "feat(thirtyone): add thirtyone"
S31="$(git rev-parse HEAD)"
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
write_review docs/reviews/task-031-r1.md "$S31" approve 0 task-031
bash scripts/devloop/gate.sh --quiet >/dev/null 2>&1
git switch -q main
git merge -q --ff-only task/031-ff
printf '\n<!-- bookkeeping ff probe -->\n' >> docs/STATE.md
git add docs/STATE.md
git commit -q -m "chore(state): probe bookkeeping over a non-integration tip"
D_OUT="$(bash scripts/devloop/doctor.sh 2>&1)"; D_CODE=$?
[ "$D_CODE" -ne 0 ] && ok "doctor refuses a bookkeeping commit over a non-integration tip" \
  || ko "doctor refuses a bookkeeping commit over a non-integration tip"
printf '%s' "$D_OUT" | grep -q "not an integration merge" \
  && ok "doctor names the missing integration" || ko "doctor names the missing integration"
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
printf '\nALLOW_MAIN_PUSH=1\n' >> .devloop.conf
expect_fail "pre-push ignores a repo-local ALLOW_MAIN_PUSH" env -u ALLOW_MAIN_PUSH git push -q origin main
git checkout -q -- .devloop.conf
expect_ok "ALLOW_MAIN_PUSH=1 overrides deliberately" env ALLOW_MAIN_PUSH=1 git push -q origin main
new_branch task/007-push
printf '\nexport const pushed = 1;\n' >> src/math.js
git commit -qam "chore(math): touch for push test"
expect_ok "pre-push allows a task branch" git push -q origin task/007-push
git reset -q --hard HEAD~1
expect_fail "pre-push blocks a non-fast-forward push" git push -q --force origin task/007-push
git switch -q main

say "install safety"
INSTALL="$SRC/dist/devloop-skill/install.sh"

CUSTOM="$TMP/install-custom"
mkdir -p "$CUSTOM/.githooks" "$CUSTOM/.github/workflows" "$CUSTOM/docs" "$CUSTOM/scripts/devloop"
printf '#!/bin/sh\necho custom-pre-commit\n' > "$CUSTOM/.githooks/pre-commit"
printf '#!/bin/sh\necho custom-commit-msg\n' > "$CUSTOM/.githooks/commit-msg"
printf 'name: my-ci\non: [push]\n' > "$CUSTOM/.github/workflows/ci.yml"
printf '# my lessons\n- keep me\n' > "$CUSTOM/docs/LESSONS.md"
printf '#!/bin/sh\necho deploy\n' > "$CUSTOM/scripts/devloop/deploy.sh"
git -C "$CUSTOM" init -q -b main
git -C "$CUSTOM" config user.name t; git -C "$CUSTOM" config user.email t@x.invalid
git -C "$CUSTOM" add -A; git -C "$CUSTOM" commit -q -m "chore: custom repo"
OUT="$( cd "$CUSTOM" && bash "$INSTALL" 2>&1 )"; CODE=$?
[ "$CODE" -ne 0 ] && ok "installer refuses to overwrite a kit file" || ko "installer refuses to overwrite a kit file"
printf '%s' "$OUT" | grep -q "refusing to overwrite" \
  && ok "refusal names the conflicting files" || ko "refusal names the conflicting files"
grep -q custom-pre-commit "$CUSTOM/.githooks/pre-commit" && ok "custom hook preserved by refusal" || ko "custom hook preserved by refusal"
grep -q custom-commit-msg "$CUSTOM/.githooks/commit-msg" && ok "conflicting hook untouched by refusal" || ko "conflicting hook untouched by refusal"
grep -q "name: my-ci" "$CUSTOM/.github/workflows/ci.yml" && ok "custom workflow preserved" || ko "custom workflow preserved"
grep -q "keep me" "$CUSTOM/docs/LESSONS.md" && ok "custom lessons preserved" || ko "custom lessons preserved"
[ -f "$CUSTOM/scripts/devloop/deploy.sh" ] && ok "custom script preserved by refusal" || ko "custom script preserved by refusal"

OUT="$( cd "$CUSTOM" && bash "$INSTALL" --force 2>&1 )"; CODE=$?
[ "$CODE" -eq 0 ] && ok "installer --force succeeds" || ko "installer --force succeeds"
COMMON="$(git -C "$CUSTOM" rev-parse --path-format=absolute --git-common-dir)"
BACKUPS="$(find "$COMMON/devloop" -maxdepth 1 -type d -name 'backup-*' 2>/dev/null | head -1)"
[ -n "$BACKUPS" ] && ok "force install keeps a backup" || ko "force install keeps a backup"
[ -f "$BACKUPS/.githooks/commit-msg" ] && ok "backup contains the replaced hook" || ko "backup contains the replaced hook"
[ -f "$CUSTOM/.githooks/pre-commit" ] && ok "unknown hook is not deleted by force" || ko "unknown hook is not deleted by force"
[ -f "$CUSTOM/scripts/devloop/deploy.sh" ] && ok "unknown script is not deleted by force" || ko "unknown script is not deleted by force"
[ -f "$CUSTOM/.github/workflows/ci.yml" ] && [ -f "$CUSTOM/.github/workflows/devloop-ci.yml" ] \
  && ok "workflow installs as devloop-ci.yml next to the existing ci.yml" \
  || ko "workflow installs as devloop-ci.yml next to the existing ci.yml"
[ -f "$CUSTOM/.github/workflows/devloop-main-guard.yml" ] \
  && ok "installer ships the main-guard workflow" || ko "installer ships the main-guard workflow"
[ -f "$CUSTOM/scripts/devloop/gate.sh" ] && ok "kit installed after force" || ko "kit installed after force"
[ "$(stat -c %a "$CUSTOM/.githooks/pre-commit")" = "644" ] \
  && ok "custom hook keeps its mode after --force" || ko "custom hook keeps its mode after --force"
[ "$(stat -c %a "$CUSTOM/scripts/devloop/deploy.sh")" = "644" ] \
  && ok "custom script keeps its mode after --force" || ko "custom script keeps its mode after --force"
B_BEFORE="$(find "$COMMON/devloop" -maxdepth 1 -type d -name 'backup-*' 2>/dev/null | wc -l)"
( cd "$CUSTOM" && bash "$INSTALL" --force >/dev/null 2>&1 ) || true
B_AFTER="$(find "$COMMON/devloop" -maxdepth 1 -type d -name 'backup-*' 2>/dev/null | wc -l)"
[ "$B_AFTER" -gt "$B_BEFORE" ] \
  && ok "a second forced install gets a fresh backup" || ko "a second forced install gets a fresh backup"
B_NAME="$(find "$COMMON/devloop" -maxdepth 1 -type d -name 'backup-*' -printf '%f\n' 2>/dev/null | head -1)"
printf '%s' "$B_NAME" | grep -qE '^backup-[0-9]{8}T[0-9]{6}Z-[0-9]+$' \
  && ok "backup names carry the PID suffix" || ko "backup names carry the PID suffix"

FRESH="$TMP/install-fresh"
mkdir -p "$FRESH"
git -C "$FRESH" init -q -b main
OUT="$( cd "$FRESH" && bash "$INSTALL" 2>&1 )"; CODE=$?
[ "$CODE" -eq 0 ] && ok "installer succeeds in a fresh repo" || ko "installer succeeds in a fresh repo"
[ -f "$FRESH/.devloop.conf" ] && ok "fresh install writes .devloop.conf" || ko "fresh install writes .devloop.conf"
[ -f "$FRESH/scripts/devloop/gate.sh" ] && ok "fresh install writes the kit scripts" || ko "fresh install writes the kit scripts"
[ -f "$FRESH/.github/workflows/devloop-ci.yml" ] && ok "fresh install writes devloop-ci.yml" || ko "fresh install writes devloop-ci.yml"
[ -f "$FRESH/.github/workflows/devloop-main-guard.yml" ] && ok "fresh install writes devloop-main-guard.yml" || ko "fresh install writes devloop-main-guard.yml"
grep -q "last_verified_sha: unset" "$FRESH/docs/STATE.md" \
  && ok "fresh STATE is a neutral template" || ko "fresh STATE is a neutral template"
grep -q "Append only" "$FRESH/docs/LESSONS.md" \
  && ok "fresh LESSONS is a template, not the kit history" || ko "fresh LESSONS is a template, not the kit history"
[ "$(git -C "$FRESH" config --get core.hooksPath)" = ".githooks" ] \
  && ok "fresh install configures core.hooksPath" || ko "fresh install configures core.hooksPath"
SYM="$TMP/install-symlink"
OUT="$TMP/install-outside"
mkdir -p "$SYM/scripts" "$OUT"
git -C "$SYM" init -q -b main
ln -s "$OUT" "$SYM/scripts/devloop"
SYM_OUT="$( cd "$SYM" && bash "$INSTALL" 2>&1 )"; SYM_CODE=$?
[ "$SYM_CODE" -eq 4 ] \
  && ok "installer refuses a symlinked destination" || ko "installer refuses a symlinked destination"
printf '%s' "$SYM_OUT" | grep -qi "symlink" \
  && ok "refusal names the symlink" || ko "refusal names the symlink"
[ -z "$(ls -A "$OUT" 2>/dev/null)" ] \
  && ok "installer writes nothing through the symlink" || ko "installer writes nothing through the symlink"

say "prove red"
PRR="$TMP/prove-red"
mkdir -p "$PRR/tests"
git -C "$PRR" init -q -b main
git -C "$PRR" config user.name t; git -C "$PRR" config user.email t@x.invalid
printf '#!/bin/sh\nexit 0\n' > "$PRR/tests/test.sh"
printf '#!/bin/sh\nexit 0\n' > "$PRR/tests/ok.sh"
git -C "$PRR" add -A; git -C "$PRR" commit -q -m "test: base"
printf '#!/bin/sh\nexit 1\n' > "$PRR/tests/test.sh"
printf '#!/bin/sh\necho ok; exit 0\n' > "$PRR/tests/ok.sh"
git -C "$PRR" add -A; git -C "$PRR" commit -q -m "test: red"
( cd "$PRR" && bash "$SRC/scripts/devloop/prove-red.sh" HEAD^ -- bash tests/test.sh >/dev/null 2>&1 ); CODE=$?
[ "$CODE" -eq 0 ] && ok "prove-red confirms a red test" || ko "prove-red confirms a red test"
( cd "$PRR" && bash "$SRC/scripts/devloop/prove-red.sh" HEAD^ -- bash tests/ok.sh >/dev/null 2>&1 ); CODE=$?
[ "$CODE" -eq 1 ] && ok "prove-red rejects a test that is green on the base" \
  || ko "prove-red rejects a test that is green on the base"

say "main guard"
GUARD="$SRC/.github/workflows/main-guard.yml"
GUARD_LOGIC="$SRC/scripts/devloop/main-guard.sh"
grep -q 'Merge pull request #' "$GUARD_LOGIC" \
  && ok "guard verifies the pull-request merge subject" || ko "guard verifies the pull-request merge subject"
grep -q 'gh issue create' "$GUARD_LOGIC" \
  && ok "guard reports a direct push in an issue" || ko "guard reports a direct push in an issue"
grep -q 'mergeCommit.oid' "$GUARD_LOGIC" \
  && ok "guard checks the PR merge commit SHA" || ko "guard checks the PR merge commit SHA"
grep -q 'REQUIRE_PR' "$GUARD" \
  && ok "guard skips repositories not in PR mode" || ko "guard skips repositories not in PR mode"
grep -q 'baseRefName' "$GUARD_LOGIC" && grep -q 'BASE_BRANCH' "$GUARD" \
  && ok "guard checks the PR base branch" || ko "guard checks the PR base branch"
diff -r "$SRC/.github/workflows" "$SRC/dist/devloop-skill/assets/.github/workflows" >/dev/null 2>&1 \
  && ok "bundle workflows mirror the source" || ko "bundle workflows mirror the source"
grep -q 'branches: \[main\]' "$SRC/.github/workflows/ci.yml" && ! grep -q 'task/\*\*' "$SRC/.github/workflows/ci.yml" \
  && ok "CI no longer runs twice per task branch" || ko "CI no longer runs twice per task branch"
diff -r "$SRC/.githooks" "$SRC/dist/devloop-skill/assets/.githooks" >/dev/null 2>&1 \
  && ok "bundle hooks mirror the source" || ko "bundle hooks mirror the source"
MIRROR_OK=1
for f in docs/tasks/TEMPLATE.md docs/reviews/TEMPLATE.md docs/adr/0000-template.md docs/STATE.template.md docs/LESSONS.template.md; do
  diff -q "$SRC/$f" "$SRC/dist/devloop-skill/assets/$f" >/dev/null 2>&1 || MIRROR_OK=0
done
[ "$MIRROR_OK" -eq 1 ] && ok "bundle docs templates mirror the source" || ko "bundle docs templates mirror the source"

mkdir -p "$TMP/fakebin"
cat > "$TMP/fakebin/gh" <<'FAKE'
#!/usr/bin/env bash
set -u
case "${1:-} ${2:-}" in
  "api repos/o/r/commits/"*)
    [ "${FAKE_API_FAIL:-0}" -eq 1 ] && exit 1
    printf '%s\n' "${FAKE_SUBJECT:-}"; exit 0 ;;
  "pr view")
    printf '%s\n' "${FAKE_PR_VIEW:-}"; exit 0 ;;
  "issue create")
    printf '%s\n' "$*" >> "${FAKE_ISSUE_LOG:?}"; exit 0 ;;
  *) exit 1 ;;
esac
FAKE
chmod +x "$TMP/fakebin/gh"
G_SHA="$(printf 'a%.0s' {1..40})"
G_LOG="$TMP/guard-issues.log"
guard_run() {
  : > "$G_LOG"
  local rc=0
  env PATH="$TMP/fakebin:$PATH" REPO=o/r SHA="${G_SHA:-}" ACTOR=alice BEFORE=bbb \
    BASE_BRANCH=main FAKE_SUBJECT="${1:-}" FAKE_PR_VIEW="${2:-}" \
    FAKE_API_FAIL="${3:-0}" FAKE_ISSUE_LOG="$G_LOG" \
    bash "$GUARD_LOGIC" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}
CODE="$(guard_run 'Merge pull request #42 from x' "$(printf 'MERGED\t%s\tmain' "$G_SHA")")"
[ "$CODE" -eq 0 ] && [ ! -s "$G_LOG" ] \
  && ok "guard accepts a verified PR merge" || ko "guard accepts a verified PR merge"
CODE="$(guard_run 'Merge pull request #42 from x' "$(printf 'MERGED\t%s\tmain' "$(printf 'b%.0s' {1..40})")")"
[ "$CODE" -eq 1 ] && [ -s "$G_LOG" ] \
  && ok "guard rejects a mismatched merge commit" || ko "guard rejects a mismatched merge commit"
CODE="$(guard_run 'Merge pull request #42 from x' "$(printf 'MERGED\t%s\trelease' "$G_SHA")")"
[ "$CODE" -eq 1 ] && [ -s "$G_LOG" ] \
  && ok "guard rejects a non-default base branch" || ko "guard rejects a non-default base branch"
CODE="$(guard_run 'feat: direct push' '')"
[ "$CODE" -eq 1 ] && [ -s "$G_LOG" ] \
  && ok "guard rejects a non-PR subject" || ko "guard rejects a non-PR subject"
CODE="$(guard_run '' '' 1)"
[ "$CODE" -eq 1 ] && [ -s "$G_LOG" ] \
  && ok "guard reports an API failure instead of aborting" || ko "guard reports an API failure instead of aborting"
G_SHA="$(printf '0%.0s' {1..40})"
CODE="$(guard_run '' '')"
[ "$CODE" -eq 0 ] && [ ! -s "$G_LOG" ] \
  && ok "guard ignores a branch deletion" || ko "guard ignores a branch deletion"
G_SHA="$(printf 'a%.0s' {1..40})"

say "docs drift"
if grep -rq '\.devloop/artifacts' "$SRC/AGENTS.md" "$SRC/README.md" "$SRC/scripts/devloop/packet.sh" "$SRC/.agents/skills" "$SRC/dist/devloop-skill/SKILL.md" 2>/dev/null; then
  ko "hot docs no longer point at the old artifact store"
else
  ok "hot docs no longer point at the old artifact store"
fi
grep -q '## Team mode' "$SRC/dist/devloop-skill/SKILL.md" \
  && ok "entry skill documents team mode" || ko "entry skill documents team mode"
diff -r "$SRC/scripts/devloop" "$SRC/dist/devloop-skill/assets/scripts/devloop" >/dev/null 2>&1 \
  && ok "bundle scripts mirror the source" || ko "bundle scripts mirror the source"
diff -r "$SRC/.agents/skills" "$SRC/dist/devloop-skill/assets/.agents/skills" >/dev/null 2>&1 \
  && ok "bundle skills mirror the source" || ko "bundle skills mirror the source"
diff -q "$SRC/AGENTS.md" "$SRC/dist/devloop-skill/assets/AGENTS.md" >/dev/null 2>&1 \
  && ok "bundle AGENTS mirrors the source" || ko "bundle AGENTS mirrors the source"
diff -q "$SRC/.devloop.conf.example" "$SRC/dist/devloop-skill/assets/.devloop.conf.example" >/dev/null 2>&1 \
  && ok "bundle config example mirrors the source" || ko "bundle config example mirrors the source"

say "github arbiter"
PROTECT_OUT="$(bash scripts/devloop/protect.sh --dry-run 2>&1)"; PROTECT_CODE=$?
[ "$PROTECT_CODE" -eq 0 ] && ok "protect --dry-run exits 0" || ko "protect --dry-run exits 0"
printf '%s' "$PROTECT_OUT" | grep -q '"gate"' \
  && ok "protect requires the gate check" || ko "protect requires the gate check"
printf '%s' "$PROTECT_OUT" | grep -q '"allow_force_pushes": false' \
  && ok "protect forbids force-push" || ko "protect forbids force-push"
printf '%s' "$PROTECT_OUT" | grep -q '"enforce_admins": true' \
  && ok "protect enforces the rules for admins" || ko "protect enforces the rules for admins"
printf '%s' "$PROTECT_OUT" | grep -q '"required_approving_review_count": 0' \
  && ok "protect requires a pull request (zero approvals)" || ko "protect requires a pull request (zero approvals)"
printf '%s' "$PROTECT_OUT" | grep -q '"allow_deletions": false' \
  && ok "protect forbids branch deletion" || ko "protect forbids branch deletion"
expect_fail "integrate refuses --pr with --push" \
  bash scripts/devloop/integrate.sh --task task-001 --pr --push --dry-run
printf 'REQUIRE_PR="true"\n' > "$TMP/require-pr.conf"
OUT="$(env DEVLOOP_CONF="$TMP/require-pr.conf" bash scripts/devloop/integrate.sh --task task-001 2>&1 || true)"
printf '%s' "$OUT" | grep -q "REQUIRE_PR=true" \
  && ok "REQUIRE_PR refuses a local integration" || ko "REQUIRE_PR refuses a local integration"
grep -q 'REVIEW_REQUIRED' "$SRC/scripts/devloop/integrate.sh" \
  && grep -q 'reviewDecision' "$SRC/scripts/devloop/integrate.sh" \
  && ok "integrate stops when the PR needs an owner approval" \
  || ko "integrate stops when the PR needs an owner approval"

say "public readiness"
[ -f "$SRC/LICENSE" ] && grep -q "MIT License" "$SRC/LICENSE" \
  && ok "public readiness: MIT license present" || ko "public readiness: MIT license present"
[ -f "$SRC/SECURITY.md" ] && grep -qi "vulnerability" "$SRC/SECURITY.md" \
  && ok "public readiness: security policy present" || ko "public readiness: security policy present"
grep -qx ".plugin-work/" "$SRC/.gitignore" && grep -qx ".devloop/" "$SRC/.gitignore" \
  && ok "public readiness: scratch and legacy artifacts ignored" \
  || ko "public readiness: scratch and legacy artifacts ignored"
[ -f "$SRC/docs/security/pre-public-audit.md" ] \
  && ok "public readiness: audit report present" || ko "public readiness: audit report present"

say "doctor without evidence"
new_branch task/008-nogate
printf '\nexport const n = 0;\n' >> src/math.js
git commit -qam "chore(math): add n"
expect_fail "doctor flags a commit with no gate or review" bash scripts/devloop/doctor.sh
git switch -q main

say "harness check"
HC="$SRC/scripts/devloop/harness-check.sh"
HC_TMP="$TMP/harness-check"
mkdir -p "$HC_TMP"
hc_root() { # <name> ; minimal root whose AGENTS.md names the alpha skill
  mkdir -p "$HC_TMP/$1/.agents/skills/alpha"
  printf -- '---\nname: alpha\n---\n# alpha\n' > "$HC_TMP/$1/.agents/skills/alpha/SKILL.md"
  printf 'Load the `alpha` skill.\n' > "$HC_TMP/$1/AGENTS.md"
}
expect_ok "harness-check passes on the kit" bash "$HC" --root "$SRC" -q
hc_root ok
expect_ok "harness-check accepts a named skill" bash "$HC" --root "$HC_TMP/ok" -q
hc_root orphan
mkdir -p "$HC_TMP/orphan/.agents/skills/beta"
printf 'x\n' > "$HC_TMP/orphan/.agents/skills/beta/SKILL.md"
expect_fail "harness-check rejects an orphan skill" bash "$HC" --root "$HC_TMP/orphan" -q
hc_root braces
printf 'Rule {{ x }}\n' >> "$HC_TMP/braces/AGENTS.md"
expect_fail "harness-check rejects template syntax" bash "$HC" --root "$HC_TMP/braces" -q
hc_root script
printf 'Run `scripts/devloop/ghost.sh`.\n' >> "$HC_TMP/script/AGENTS.md"
expect_fail "harness-check rejects a phantom script" bash "$HC" --root "$HC_TMP/script" -q
hc_root long
for i in $(seq 1 160); do printf 'line %s\n' "$i"; done >> "$HC_TMP/long/AGENTS.md"
expect_fail "harness-check rejects an oversized AGENTS.md" bash "$HC" --root "$HC_TMP/long" -q
mkdir -p "$HC_TMP/none"
expect_fail "harness-check rejects a missing AGENTS.md" bash "$HC" --root "$HC_TMP/none" -q

say "owner-merged pr"
git remote get-url origin >/dev/null 2>&1 || git remote add origin "$TMP/remote.git"
env ALLOW_MAIN_PUSH=1 git push -q origin main
start_task task-050 050-owner-merge
printf '\nexport function minus(a, b) { return a - b; }\n' >> src/math.js
git add -A
git commit -q -m "feat(math): add minus"
bash scripts/devloop/gate.sh --quiet
HEAD_050="$(git rev-parse HEAD)"
write_review docs/reviews/task-050-r1.md "$HEAD_050" approve 0 task-050
bash scripts/devloop/gate.sh --quiet
PR_HEAD="$(git rev-parse HEAD)"
git switch -q main
git merge -q --no-ff "$PR_HEAD" -m "Merge pull request #50 from o/task/050-owner-merge"
MERGE_050="$(git rev-parse HEAD)"
env ALLOW_MAIN_PUSH=1 git push -q origin main
git switch -q task/050-owner-merge

mkdir -p "$TMP/fakebin-merge"
cat > "$TMP/fakebin-merge/gh" <<'FAKE'
#!/usr/bin/env bash
set -u
case "${1:-} ${2:-}" in
  "auth status") exit 0 ;;
  "repo view") printf 'o/r\n'; exit 0 ;;
  "pr list") printf '%s\n' "${FAKE_MERGED_JSON:-}"; exit 0 ;;
  *) exit 1 ;;
esac
FAKE
chmod +x "$TMP/fakebin-merge/gh"

MERGED_JSON="$(jq -nc --arg m "$MERGE_050" --arg h "$PR_HEAD" \
  '{number:50,url:"https://example.invalid/pr/50",mergeCommit:{oid:$m},reviewDecision:"APPROVED",headRefOid:$h}')"
expect_ok "integrate records an owner-merged PR" \
  env PATH="$TMP/fakebin-merge:$PATH" FAKE_MERGED_JSON="$MERGED_JSON" \
  bash scripts/devloop/integrate.sh --task task-050 --pr
REC="$ART_DIR/integrations/$MERGE_050.json"
[ -f "$REC" ] && ok "integration record written for the merge commit" \
  || ko "integration record written for the merge commit"
[ "$(jq -r .head_sha "$REC" 2>/dev/null)" = "$PR_HEAD" ] \
  && ok "record names the PR head" || ko "record names the PR head"
[ "$(jq -r .base "$REC" 2>/dev/null)" = "$(git rev-parse "$MERGE_050^1")" ] \
  && ok "record base is the merge first parent" || ko "record base is the merge first parent"
[ -z "$(git ls-remote --heads origin task/050-owner-merge 2>/dev/null)" ] \
  && ok "merged path does not push the branch" || ko "merged path does not push the branch"

# A single-parent (squash-style) merge must be refused.
git switch -q main
printf '\n// squashed\n' >> src/math.js
git add -A
git commit -q -m "fix(math): squashed owner merge"
SQUASH_SHA="$(git rev-parse HEAD)"
env ALLOW_MAIN_PUSH=1 git push -q origin main
git switch -q task/050-owner-merge
SQUASH_JSON="$(jq -nc --arg m "$SQUASH_SHA" --arg h "$PR_HEAD" \
  '{number:50,url:"https://example.invalid/pr/50",mergeCommit:{oid:$m},reviewDecision:"APPROVED",headRefOid:$h}')"
OUT="$(env PATH="$TMP/fakebin-merge:$PATH" FAKE_MERGED_JSON="$SQUASH_JSON" \
  bash scripts/devloop/integrate.sh --task task-050 --pr 2>&1 || true)"
printf '%s' "$OUT" | grep -q "two-parent merge" \
  && ok "integrate refuses a single-parent owner merge" \
  || ko "integrate refuses a single-parent owner merge"
FAKE_MERGE="$(printf 'f%.0s' $(seq 1 40))"
MOVED_JSON="$(jq -nc --arg m "$FAKE_MERGE" --arg h "$(printf '0%.0s' $(seq 1 40))" \
  '{number:50,url:"https://example.invalid/pr/50",mergeCommit:{oid:$m},reviewDecision:"APPROVED",headRefOid:$h}')"
OUT="$(env PATH="$TMP/fakebin-merge:$PATH" FAKE_MERGED_JSON="$MOVED_JSON" \
  bash scripts/devloop/integrate.sh --task task-050 --pr 2>&1 || true)"
printf '%s' "$OUT" | grep -q "branch moved after the merge" \
  && ok "integrate refuses a branch that moved after the merge" \
  || ko "integrate refuses a branch that moved after the merge"
[ ! -f "$ART_DIR/integrations/$FAKE_MERGE.json" ] \
  && ok "no record is written for a refused merge" || ko "no record is written for a refused merge"

say "results"
printf 'passed: %d, failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
