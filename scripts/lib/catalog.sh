#!/usr/bin/env bash
# =============================================================================
# scripts/lib/catalog.sh — Think OS plugin catalog bash library
# =============================================================================
# Source this file in other scripts to access catalog data.
#
# Usage:
#   source "$(dirname "$0")/lib/catalog.sh"   # from scripts/
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/catalog.sh"
#
# Public API:
#   catalog_path
#   catalog_list_ids
#   catalog_get_field <id> <field_path>
#   catalog_resolve_preset <preset_name>
#   catalog_filter_by_target <target>          (reads ids from stdin)
#   catalog_oauth_items                        (reads ids from stdin)
#   catalog_kind <id> <target>
#   catalog_pretty <id>
# =============================================================================

# Compute absolute path to the catalog YAML relative to this file's location.
catalog_path() {
  local _lib_dir
  _lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "${_lib_dir}/../../data/plugin-catalog.yaml"
}

# Path to the pre-rendered JSON copy of the catalog. Kept in sync with the YAML
# via scripts/lib/render-catalog.sh and used as a fallback when neither yq nor
# system PyYAML is available — Python's stdlib `json` is always present, so
# this path keeps onboarding working on a stock Homebrew Python.
catalog_json_path() {
  local _lib_dir
  _lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "${_lib_dir}/../../data/plugin-catalog.json"
}

# ---------------------------------------------------------------------------
# Internal: run a Python snippet against the catalog.
# Tries PyYAML first (parses the canonical YAML); falls back to the rendered
# JSON. The snippet receives the parsed catalog as variable `data`.
# Additional arguments ($@) are passed as argv to the Python subprocess so
# callers can pass values safely without string interpolation.
# ---------------------------------------------------------------------------
_catalog_python() {
  local snippet="$1"; shift
  python3 - "$(catalog_path)" "$(catalog_json_path)" "$@" <<PYEOF
import sys
yaml_path, json_path = sys.argv[1], sys.argv[2]
argv = sys.argv[3:]
data = None
try:
    import yaml
    with open(yaml_path) as fh:
        data = yaml.safe_load(fh)
except ModuleNotFoundError:
    import json, os
    if not os.path.exists(json_path):
        sys.stderr.write(
            "catalog.sh: PyYAML not available and no rendered JSON at "
            + json_path + ".\\n"
            "Run scripts/lib/render-catalog.sh (requires PyYAML once) to regenerate.\\n"
        )
        sys.exit(1)
    with open(json_path) as fh:
        data = json.load(fh)
$snippet
PYEOF
}

# catalog_yq removed in v0.8 — was an eval-based debug helper with no live callers.

# Print all catalog ids, one per line.
catalog_list_ids() {
  _catalog_python "
for entry in data.get('catalog', []):
    print(entry['id'])
"
}

# Print a single field value for a given catalog id.
# Supports dotted paths, e.g. cowork.registry_id or claude_code.url
catalog_get_field() {
  local id="$1"
  local field_path="$2"
  _catalog_python "
target_id, field_path = argv[0], argv[1]
keys = field_path.split('.')
for entry in data.get('catalog', []):
    if entry.get('id') == target_id:
        val = entry
        for k in keys:
            if isinstance(val, dict): val = val.get(k)
            else: val = None
            if val is None: break
        if val is not None: print(val)
        break
" "$id" "$field_path"
}

# Print catalog ids in a named preset, one per line.
# Exits with error if the preset is not found.
catalog_resolve_preset() {
  local preset="$1"
  _catalog_python "
preset_name = argv[0]
presets = data.get('presets', {})
if preset_name not in presets:
    import sys
    print('catalog_resolve_preset: preset not found: ' + preset_name, file=sys.stderr)
    sys.exit(1)
for item_id in presets[preset_name].get('items', []):
    print(item_id)
" "$preset"
}

# Read ids from stdin; print only those where <target>.available is true.
# target: cowork | claude_code
catalog_filter_by_target() {
  local target="$1"
  local id_list
  id_list="$(cat)"
  _catalog_python "
target, id_list_raw = argv[0], argv[1]
id_list = id_list_raw.splitlines()
catalog = {e['id']: e for e in data.get('catalog', [])}
for item_id in id_list:
    item_id = item_id.strip()
    if not item_id: continue
    entry = catalog.get(item_id, {})
    target_block = entry.get(target, {})
    if isinstance(target_block, dict) and target_block.get('available', False):
        print(item_id)
" "$target" "$id_list"
}

# Read ids from stdin; print only those where oauth is true.
catalog_oauth_items() {
  local id_list
  id_list="$(cat)"
  _catalog_python "
id_list = argv[0].splitlines()
catalog = {e['id']: e for e in data.get('catalog', [])}
for item_id in id_list:
    item_id = item_id.strip()
    if not item_id: continue
    entry = catalog.get(item_id, {})
    if entry.get('oauth', False):
        print(item_id)
" "$id_list"
}

# Print the kind field for an id + target combination.
# e.g. catalog_kind slack claude_code => mcp_remote
catalog_kind() {
  local id="$1"
  local target="$2"
  catalog_get_field "$id" "${target}.kind"
}

# Print "Name (category)" for human display.
catalog_pretty() {
  local id="$1"
  _catalog_python "
target_id = argv[0]
for entry in data.get('catalog', []):
    if entry.get('id') == target_id:
        print('{} ({})'.format(entry.get('name','?'), entry.get('category','?')))
        break
" "$id"
}
