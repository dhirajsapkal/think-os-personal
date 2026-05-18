#!/usr/bin/env bash
# =============================================================================
# scripts/lib/lint-catalog.sh — Lint the plugin catalog for common errors.
# =============================================================================
# Exits non-zero if any of these are found:
# - Any catalog entry has `url:` containing the substring `TODO`.
# - Any entry has `url_verified: false` but is referenced from a preset.
# - YAML and rendered JSON are out of sync.
# - Any preset references a catalog id that doesn't exist.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
YAML_PATH="$REPO_ROOT/data/plugin-catalog.yaml"
JSON_PATH="$REPO_ROOT/data/plugin-catalog.json"

if [[ ! -f "$YAML_PATH" ]]; then
  echo "lint-catalog: YAML not found at $YAML_PATH" >&2
  exit 1
fi

python3 - <<'PY' "$YAML_PATH" "$JSON_PATH"
import sys, json
yaml_path, json_path = sys.argv[1], sys.argv[2]

try:
    import yaml
    with open(yaml_path) as fh: y = yaml.safe_load(fh)
except ModuleNotFoundError:
    import os
    if not os.path.exists(json_path):
        print("ERR: PyYAML unavailable and no JSON to fall back to", file=sys.stderr)
        sys.exit(1)
    with open(json_path) as fh: y = json.load(fh)

errors = []

# Check 1: no TODO in URL fields
for entry in y.get('catalog', []):
    cc = entry.get('claude_code', {})
    url = cc.get('url', '') if isinstance(cc, dict) else ''
    if isinstance(url, str) and 'TODO' in url:
        errors.append(f"TODO in url for {entry['id']}: {url}")

# Check 2: unverified entries not in presets
unverified = {e['id'] for e in y.get('catalog', []) if e.get('claude_code', {}).get('url_verified') is False}
for pname, pinfo in y.get('presets', {}).items():
    bad = set(pinfo.get('items', [])) & unverified
    if bad:
        errors.append(f"preset {pname} contains unverified entries: {sorted(bad)}")

# Check 3: preset items exist in catalog
catalog_ids = {e['id'] for e in y.get('catalog', [])}
for pname, pinfo in y.get('presets', {}).items():
    missing = set(pinfo.get('items', [])) - catalog_ids
    if missing:
        errors.append(f"preset {pname} references nonexistent ids: {sorted(missing)}")

# Check 4: YAML and JSON sync (if both exist)
import os
if os.path.exists(json_path):
    with open(json_path) as fh: j = json.load(fh)
    if json.dumps(y, sort_keys=True) != json.dumps(j, sort_keys=True):
        errors.append("YAML and JSON catalogs are out of sync. Run scripts/lib/render-catalog.sh")

if errors:
    print("CATALOG LINT FAILED:")
    for e in errors: print(f"  - {e}")
    sys.exit(1)
print("catalog lint: OK")
PY
