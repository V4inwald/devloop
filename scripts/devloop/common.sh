#!/usr/bin/env bash
# Shared helpers for the devloop scripts. Source only; never execute directly.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || { echo "devloop: not inside a git repository" >&2; exit 2; }
cd "$ROOT"

# Defaults. A project may override any of them in .devloop.conf.
MAIN_BRANCH="main"
MAX_DIFF_LINES="400"
REQUIRE_CI="false"
PROTECTED_BRANCHES="main master"
CONTRACT_PATHS=""

# shellcheck disable=SC1090
[ -f "${DEVLOOP_CONF:-$ROOT/.devloop.conf}" ] && . "${DEVLOOP_CONF:-$ROOT/.devloop.conf}"

# The default contract paths are a literal, not a sourced variable: the branch
# under review cannot remove the paths that protect the loop itself. A project
# may add paths in .devloop.conf, never subtract the core ones.
CONTRACT_PATHS=".devloop.conf scripts/devloop .githooks .github/workflows AGENTS.md${CONTRACT_PATHS:+ $CONTRACT_PATHS}"

# --- evidence store ---------------------------------------------------------
# Artifacts live in the git common directory, not in the worktree. Two
# consequences: every worktree of this repository shares one evidence store,
# and running the gate never creates an untracked file, so a fresh clone cannot
# turn the next run dirty. CI may relocate the store with DEVLOOP_ARTIFACTS to
# avoid writing inside .git.
git_common_dir() {
  local d
  d="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -z "$d" ]; then
    d="$(git rev-parse --git-common-dir 2>/dev/null || true)"
    [ -n "$d" ] || d=".git"
    case "$d" in
      /*) ;;
      *) d="$ROOT/$d" ;;
    esac
    d="$(cd "$d" 2>/dev/null && pwd -P || printf '%s' "$d")"
  fi
  printf '%s' "$d"
}
GIT_COMMON_DIR="$(git_common_dir)"
ART="${DEVLOOP_ARTIFACTS:-$GIT_COMMON_DIR/devloop}"

die() { echo "devloop: $*" >&2; exit 2; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

head_sha() { git rev-parse HEAD; }
current_branch() { git rev-parse --abbrev-ref HEAD; }

# True when tracked or untracked work exists outside HEAD.
is_dirty() {
  ! git diff --quiet --ignore-submodules -- \
    || ! git diff --cached --quiet --ignore-submodules -- \
    || [ -n "$(git ls-files --others --exclude-standard)" ]
}

# Merge base against the main branch, with fallbacks for local-only repos.
merge_base() {
  local ref=""
  if git rev-parse --verify --quiet "origin/${MAIN_BRANCH}" >/dev/null; then
    ref="origin/${MAIN_BRANCH}"
  elif git rev-parse --verify --quiet "${MAIN_BRANCH}" >/dev/null; then
    ref="${MAIN_BRANCH}"
  fi
  if [ -n "$ref" ]; then
    git merge-base HEAD "$ref"
  else
    git rev-list --max-parents=0 HEAD | tail -1
  fi
}

# Read one key from the YAML frontmatter of a markdown file. A missing key is
# an empty value, not an error: callers run under `set -e`.
fm() {
  sed -n '/^---[[:space:]]*$/,/^---[[:space:]]*$/p' "$1" \
    | grep -E "^$2:" \
    | head -1 \
    | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]*$//; s/^[\"']//; s/[\"']$//" \
    || true
}

# Added + removed lines outside review evidence. The size limit exists to keep
# the change reviewable; verdict files are the output of the review, not the
# change, and counting them would let evidence consume the budget it protects.
diff_lines() {
  git diff --numstat "$1..HEAD" \
    | awk '$3 !~ /^docs\/reviews\// { a += $1; d += $2 } END { print a + d + 0 }'
}

changed_files() { git diff --name-only "$1..HEAD"; }
