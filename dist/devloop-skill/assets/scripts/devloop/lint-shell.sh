#!/usr/bin/env bash
# Run from the repository root. bash -n accepts only one script, not a list.
set -euo pipefail
shopt -s nullglob
files=(scripts/devloop/*.sh .githooks/* tests/*.sh)
[ "${#files[@]}" -gt 0 ] || { echo 'lint-shell: no scripts found' >&2; exit 2; }
for file in "${files[@]}"; do
  [ -f "$file" ] || continue
  bash -n -- "$file"
done
