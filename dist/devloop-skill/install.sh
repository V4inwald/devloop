#!/usr/bin/env bash
# Install the devloop kit (enforcement layer + templates) into the current git repository.
#
# Usage: install.sh [--force] [--dry-run]
#   --force     overwrite files that already exist (a timestamped backup is kept
#               under <git-common-dir>/devloop/backup-<utc>)
#   --dry-run   print what would be installed or kept; write nothing
#
# Never overwrites: .devloop.conf, docs/STATE.md, docs/LESSONS.md, AGENTS.md.
# Installs the CI workflow as .github/workflows/devloop-ci.yml so an existing
# ci.yml is never clobbered.
#
# Exit: 0 installed, 2 usage/repo error, 3 already installed (no --force),
#       4 conflicts found (no --force).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$HERE/assets"

die() { echo "devloop install: $*" >&2; exit 2; }
usage() { sed -n '2,16p' "${BASH_SOURCE[0]}"; }

FORCE=0
DRY=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

[ -d "$ASSETS" ] || die "assets/ missing next to install.sh"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || die "not inside a git repository; run 'git init' first"
cd "$ROOT"

GIT_COMMON="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [ -z "$GIT_COMMON" ]; then
  GIT_COMMON="$(git rev-parse --git-common-dir 2>/dev/null || echo .git)"
  case "$GIT_COMMON" in /*) ;; *) GIT_COMMON="$ROOT/$GIT_COMMON" ;; esac
fi
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP="$GIT_COMMON/devloop/backup-$STAMP"

if [ -f scripts/devloop/gate.sh ] && [ "$FORCE" -ne 1 ]; then
  echo "devloop is already installed in $ROOT"
  echo "re-run with --force to overwrite the kit files (a backup is kept)"
  exit 3
fi

# Every file in assets/ is a candidate. The CI workflow and the live state are
# special-cased so the installer never takes over an existing project file.
targets() {
  local rel dst
  while IFS= read -r rel; do
    case "$rel" in
      AGENTS.md) continue ;;
      .devloop.conf.example) continue ;;
      docs/STATE.md) continue ;;
      docs/STATE.template.md) dst="docs/STATE.md" ;;
      docs/LESSONS.template.md) dst="docs/LESSONS.md" ;;
      .github/workflows/ci.yml) dst=".github/workflows/devloop-ci.yml" ;;
      .github/workflows/main-guard.yml) dst=".github/workflows/devloop-main-guard.yml" ;;
      .github/workflows/*) dst=".github/workflows/devloop-$(basename "$rel")" ;;
      *) dst="$rel" ;;
    esac
    printf '%s\t%s\n' "$rel" "$dst"
  done < <(cd "$ASSETS" && find . -type f -print | sed 's|^\./||' | sort)
}

# Paths that are never overwritten, even with --force.
KEEP_IF_PRESENT=" docs/STATE.md docs/LESSONS.md .devloop.conf "

CONFLICTS=""
while IFS=$'\t' read -r _ dst; do
  [ -e "$dst" ] || continue
  case "$KEEP_IF_PRESENT" in *" $dst "*) continue ;; esac
  CONFLICTS="$CONFLICTS $dst"
done < <(targets)
if [ -e AGENTS.md ] && [ -e AGENTS.devloop.md ]; then
  CONFLICTS="$CONFLICTS AGENTS.devloop.md"
fi

if [ -n "$CONFLICTS" ] && [ "$FORCE" -ne 1 ]; then
  echo "devloop install: refusing to overwrite existing files:" >&2
  for f in $CONFLICTS; do echo "  $f" >&2; done
  echo "re-run with --force to replace them (a timestamped backup is kept)" >&2
  exit 4
fi

backup() { # <path>
  local p="$1"
  [ -e "$p" ] || return 0
  mkdir -p "$BACKUP/$(dirname "$p")"
  cp -a "$p" "$BACKUP/$p"
}

echo "devloop install: $ROOT"
if [ "$DRY" -eq 1 ]; then echo "  (dry run: nothing will be written)"; fi

while IFS=$'\t' read -r rel dst; do
  [ -n "$dst" ] || continue
  if [ -e "$dst" ]; then
    case "$KEEP_IF_PRESENT" in
      *" $dst "*) echo "  keep   $dst"; continue ;;
    esac
    if [ "$FORCE" -eq 1 ] && [ "$DRY" -eq 1 ]; then
      echo "  would backup $dst"
    fi
  fi
  if [ "$DRY" -eq 1 ]; then
    echo "  would install $dst"
    continue
  fi
  mkdir -p "$(dirname "$dst")"
  [ "$FORCE" -eq 1 ] && backup "$dst"
  cp -a "$ASSETS/$rel" "$dst"
  echo "  install $dst"
done < <(targets)

# AGENTS.md is never overwritten. A contract goes next to it only when one
# already exists and does not mention devloop.
if [ ! -e AGENTS.md ]; then
  if [ "$DRY" -eq 1 ]; then echo "  would install AGENTS.md"
  else cp -a "$ASSETS/AGENTS.md" AGENTS.md; echo "  install AGENTS.md"; fi
elif grep -qi "devloop" AGENTS.md; then
  echo "  keep   AGENTS.md (already references devloop)"
elif [ -e AGENTS.devloop.md ] && [ "$FORCE" -ne 1 ]; then
  echo "  keep   AGENTS.devloop.md"
else
  if [ "$DRY" -eq 1 ]; then echo "  would install AGENTS.devloop.md"
  else
    [ "$FORCE" -eq 1 ] && backup AGENTS.devloop.md
    cp -a "$ASSETS/AGENTS.md" AGENTS.devloop.md
    echo "  install AGENTS.devloop.md (merge it into AGENTS.md by hand; DSH only loads AGENTS.md)"
  fi
fi

if [ -f .devloop.conf ]; then
  echo "  keep   .devloop.conf"
elif [ "$DRY" -eq 1 ]; then
  echo "  would install .devloop.conf"
else
  cp -a "$ASSETS/.devloop.conf.example" .devloop.conf
  echo "  install .devloop.conf (edit the CHECK_* commands before the first gate)"
fi

if [ "$DRY" -eq 0 ]; then
  chmod +x .githooks/* scripts/devloop/*.sh 2>/dev/null || true

  CURRENT_HOOKS_PATH="$(git config --get core.hooksPath || true)"
  if [ -z "$CURRENT_HOOKS_PATH" ] || [ "$CURRENT_HOOKS_PATH" = ".githooks" ]; then
    git config core.hooksPath .githooks
    echo "  hooks  core.hooksPath=.githooks"
  else
    echo "  hooks  core.hooksPath is '$CURRENT_HOOKS_PATH': hooks NOT installed."
    echo "         merge .githooks into that setup, or set core.hooksPath=.githooks"
  fi
fi

if [ -d "$BACKUP" ]; then
  echo "backup: ${BACKUP#"$ROOT"/}"
fi

echo
echo "devloop installed in $ROOT"
echo "next:"
echo "  1. edit .devloop.conf so CHECK_TEST / CHECK_LINT match this project"
echo "  2. bash scripts/devloop/gate.sh"
echo "  3. read .agents/skills/dev-cycle/SKILL.md (full procedure)"
