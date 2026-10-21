#!/usr/bin/env bash
# Refresh the bundled assets from a local checkout of the devloop kit.
# Only needed when you maintain the kit; normal installations do not call this.
#
# Usage: [DEVLOOP_KIT_SRC=/path/to/kit] refresh.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${DEVLOOP_KIT_SRC:-$(cd "$HERE/../.." && pwd)}"

[ -f "$SRC/scripts/devloop/gate.sh" ] || { echo "refresh: $SRC does not look like the devloop kit" >&2; exit 2; }
[ -d "$HERE/assets" ] || { echo "refresh: assets/ missing" >&2; exit 2; }

cd "$SRC"
rm -rf "$HERE/assets"
mkdir -p "$HERE/assets/docs/tasks" "$HERE/assets/docs/reviews" "$HERE/assets/docs/adr"

cp -a AGENTS.md .devloop.conf.example scripts .githooks .github .agents "$HERE/assets/"
cp -a docs/tasks/TEMPLATE.md "$HERE/assets/docs/tasks/"
cp -a docs/reviews/TEMPLATE.md "$HERE/assets/docs/reviews/"
cp -a docs/adr/0000-template.md "$HERE/assets/docs/adr/"
cp -a docs/STATE.template.md docs/LESSONS.template.md "$HERE/assets/docs/"

echo "refreshed $HERE/assets from $SRC (HEAD $(git rev-parse --short HEAD))"
