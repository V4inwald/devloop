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

# shellcheck disable=SC1090
[ -f "${DEVLOOP_CONF:-$ROOT/.devloop.conf}" ] && . "${DEVLOOP_CONF:-$ROOT/.devloop.conf}"

ART="$ROOT/.devloop/artifacts"

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

# Read one key from the YAML frontmatter of a markdown file.
fm() {
  sed -n '/^---[[:space:]]*$/,/^---[[:space:]]*$/p' "$1" \
    | grep -E "^$2:" \
    | head -1 \
    | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]*$//; s/^[\"']//; s/[\"']$//"
}

diff_lines() { # <base> -> added + removed lines
  git diff --numstat "$1..HEAD" | awk '{ a += $1; d += $2 } END { print a + d + 0 }'
}

changed_files() { git diff --name-only "$1..HEAD"; }
