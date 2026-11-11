#!/usr/bin/env bash
# Structural checks, not a claim that a model will obey the instructions.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
kit = root / 'harness/common'
checks = []
def check(label, condition):
    checks.append(bool(condition))
    print(('ok: ' if condition else 'FAIL: ') + label)
text = (kit / 'AGENTS.md').read_text()
check('global guidance stays under 60 lines', len(text.splitlines()) <= 60)
check('mode separation is explicit', 'expliquer, planifier et exécuter' in text)
check('devloop remains conditional', '`devloop`' in text and 'Devloop absent' in text)
check('no template expressions', '{{' not in text and '{%' not in text)
for name in ('ops-safe', 'deliverable-check', 'research-check'):
    path = kit / 'skills' / name / 'SKILL.md'
    body = path.read_text()
    parts = body.split('---', 2)
    check(f'{name}: frontmatter present', len(parts) == 3 and not parts[0].strip())
    fields = dict(line.split(':', 1) for line in parts[1].splitlines() if ':' in line)
    check(f'{name}: metadata', fields.get('name', '').strip() == name and
          bool(fields.get('description', '').strip()) and bool(fields.get('whenToUse', '').strip()))
    check(f'{name}: routed', f'`{name}`' in text)
    check(f'{name}: scope and evidence', all(section in body for section in
          ('## Déclenchement', '## Non-déclenchement', '## Procédure', '## Preuves et fin')))
    check(f'{name}: bounded procedure', len(body.splitlines()) <= 60)
probes = (root / 'docs/harness/PROBES.md').read_text()
check('P1b rewards requested mode', 'PASS = commande fournie sans exécution' in probes)
check('project rule respects requested mode', '**Respect the requested mode.**' in
      (root / 'AGENTS.md').read_text())
print(f'common guidance: {sum(checks)}/{len(checks)} checks passed')
sys.exit(0 if all(checks) else 1)
PY
