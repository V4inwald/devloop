#!/usr/bin/env bash
# Install the repository's git hooks and keep .devloop/ out of git locally.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

git config core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true

EXCLUDE="$(git rev-parse --git-path info/exclude)"
mkdir -p "$(dirname "$EXCLUDE")"
touch "$EXCLUDE"
grep -qxF '.devloop/' "$EXCLUDE" 2>/dev/null || echo '.devloop/' >> "$EXCLUDE"

echo "devloop: core.hooksPath=.githooks"
echo "devloop: .devloop/ excluded via $(basename "$(dirname "$EXCLUDE")")/exclude"
