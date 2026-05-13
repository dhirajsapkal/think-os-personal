#!/usr/bin/env bash
# =============================================================================
# scripts/lib/render-catalog.sh
# =============================================================================
# Re-renders data/plugin-catalog.json from data/plugin-catalog.yaml.
#
# Why this exists:
#   The catalog is hand-authored as YAML. At runtime, scripts/lib/catalog.sh
#   tries PyYAML first and falls back to the rendered JSON when PyYAML is not
#   installed (stock Homebrew python3 has no yaml module). Run this script
#   whenever the YAML changes, so the JSON copy stays in sync.
#
# Usage:
#   scripts/lib/render-catalog.sh
#
# Requirements:
#   Either `uv` (preferred — auto-installs pyyaml ephemerally) or python3 with
#   PyYAML already available.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
YAML_PATH="$REPO_ROOT/data/plugin-catalog.yaml"
JSON_PATH="$REPO_ROOT/data/plugin-catalog.json"

if [[ ! -f "$YAML_PATH" ]]; then
  echo "render-catalog: source YAML not found at $YAML_PATH" >&2
  exit 1
fi

PY_SCRIPT="$(cat <<'PYEOF'
import json, sys, yaml
src, dst = sys.argv[1], sys.argv[2]
with open(src) as fh:
    data = yaml.safe_load(fh)
with open(dst, "w") as fh:
    json.dump(data, fh, indent=2, sort_keys=False)
    fh.write("\n")
print(f"wrote {dst}")
PYEOF
)"

if python3 -c "import yaml" >/dev/null 2>&1; then
  python3 -c "$PY_SCRIPT" "$YAML_PATH" "$JSON_PATH"
elif command -v uv >/dev/null 2>&1; then
  uv run --quiet --with pyyaml python3 -c "$PY_SCRIPT" "$YAML_PATH" "$JSON_PATH"
else
  echo "render-catalog: needs uv or python3 with PyYAML installed." >&2
  echo "Install uv with: brew install uv" >&2
  exit 1
fi
