#!/usr/bin/env bash
# Isolated negative tests: require the intended refusal, not just any failure.
set -euo pipefail
unset DEVLOOP_ARTIFACTS DEVLOOP_CONF DEVLOOP_LEGACY_ARTIFACTS
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_TMP="$(realpath "${TMPDIR:-/tmp}")"
TMP="$(mktemp -d "$BASE_TMP/devloop-proof.XXXXXX")"
cleanup() {
  [[ "$(realpath "$TMP")" == "$TMP" && "$TMP" == "$BASE_TMP"/devloop-proof.* ]] || return 1
  rm -rf -- "${TMP:?}"
}
trap cleanup EXIT
PASS=0; FAIL=0
check() {
  local label="$1"; shift
  if "$@"; then PASS=$((PASS + 1)); echo "ok: $label"
  else FAIL=$((FAIL + 1)); echo "FAIL: $label"; fi
}
fixture() {
  REPO="$TMP/$1"; mkdir -p "$REPO/scripts/devloop"
  cp "$SRC/scripts/devloop/"{common,gate}.sh "$REPO/scripts/devloop/"
  git -C "$REPO" init -q -b main
  git -C "$REPO" config user.name 'devloop test'
  git -C "$REPO" config user.email 'devloop@example.invalid'
  printf 'original\n' > "$REPO/tracked.txt"
  printf 'CHECK_TEST=%q\n' "$2" > "$REPO/.devloop.conf"
  git -C "$REPO" add .
  git -C "$REPO" commit -qm 'chore: create integrity fixture'
  SHA="$(git -C "$REPO" rev-parse HEAD)"
  RESULT="$REPO/.git/devloop/gate/$SHA/result.json"
}
run_gate() {
  CODE=0
  (cd "$REPO" && bash scripts/devloop/gate.sh) > "$TMP/output" 2>&1 || CODE=$?
}
fixture clean 'test -f tracked.txt'
run_gate
check 'clean gate exits 0' test "$CODE" -eq 0
check 'clean evidence is integrable' jq -e '.ok == true and .dirty == false' "$RESULT"
fixture failure 'exit 7'
run_gate
check 'check failure exits 1' test "$CODE" -eq 1
check 'failed command retains its exit code' jq -e '.ok == false and .checks[0].exit == 7' "$RESULT"
for kind in tracked untracked staged commit; do
  case "$kind" in
    tracked) command='printf changed >> tracked.txt' ;;
    untracked) command='printf changed > extra.txt' ;;
    staged) command='printf changed >> tracked.txt; git add tracked.txt' ;;
    commit) command='git commit --allow-empty -qm "chore: move fixture head"' ;;
  esac
  fixture "$kind" "$command"
  run_gate
  check "$kind mutation exits 3" test "$CODE" -eq 3
  check "$kind mutation is not an integrable pass" jq -e '.dirty == true or .ok == false' "$RESULT"
  check "$kind mutation is explicitly unverified" grep -q 'UNVERIFIED' "$TMP/output"
  if [ "$kind" = commit ]; then
    check 'HEAD move records both commits' jq -e --arg sha "$SHA" \
      '.sha == $sha and .head_after != $sha and .head_changed == true' "$RESULT"
  fi
done
fixture dirty_then_clean 'git restore tracked.txt'
printf changed >> "$REPO/tracked.txt"
run_gate
check 'initial dirt remains non-integrable after cleanup' test "$CODE" -eq 3
check 'initial dirt remains recorded' jq -e '.dirty == true' "$RESULT"
LINT="$SRC/scripts/devloop/lint-shell.sh"
if [ ! -f "$LINT" ]; then
  check 'lint helper exists' test -f "$LINT"
else
  mkdir -p "$TMP/lint/scripts/devloop" "$TMP/lint/.githooks"
  printf 'echo ok\n' > "$TMP/lint/scripts/devloop/a.sh"
  printf 'if\n' > "$TMP/lint/scripts/devloop/z broken.sh"
  CODE=0; (cd "$TMP/lint" && bash "$LINT") > "$TMP/lint-output" 2>&1 || CODE=$?
  check 'second script syntax error is rejected' test "$CODE" -eq 2
  check 'syntax error identifies second script' grep -q 'z broken.sh' "$TMP/lint-output"
  printf 'echo ok\n' > "$TMP/lint/scripts/devloop/z broken.sh"
  printf 'echo ok\n' > "$TMP/lint/.githooks/a"
  printf 'if\n' > "$TMP/lint/.githooks/z"
  CODE=0; (cd "$TMP/lint" && bash "$LINT") > "$TMP/lint-output" 2>&1 || CODE=$?
  check 'second hook syntax error is rejected' test "$CODE" -eq 2
  check 'syntax error identifies second hook' grep -q '.githooks/z' "$TMP/lint-output"
  printf 'echo ok\n' > "$TMP/lint/.githooks/z"
  check 'valid scripts and spaced filename pass' bash -c 'cd "$1" && bash "$2"' _ "$TMP/lint" "$LINT"
fi
printf 'proof integrity: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
