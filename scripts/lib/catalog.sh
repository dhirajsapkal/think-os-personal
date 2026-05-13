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
#   catalog_yq <query>
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

# ---------------------------------------------------------------------------
# Internal: run a Python snippet against the catalog YAML.
# Usage: _catalog_python <python_expression_string>
# The snippet receives the parsed YAML as variable `data`.
# ---------------------------------------------------------------------------
_catalog_python() {
  local snippet="$1"
  python3 - "$(catalog_path)" <<PYEOF
import sys, yaml
with open(sys.argv[1]) as fh:
    data = yaml.safe_load(fh)
$snippet
PYEOF
}

# Run a yq-style expression against the catalog.
# Prefers yq if available; falls back to python3+PyYAML.
catalog_yq() {
  local query="$1"
  local cat_file
  cat_file="$(catalog_path)"
  if command -v yq >/dev/null 2>&1; then
    yq "$query" "$cat_file"
  elif command -v python3 >/dev/null 2>&1; then
    _catalog_python "
import json
result = eval(\"$query\", {\"data\": data})
if isinstance(result, (dict, list)):
    print(json.dumps(result, indent=2))
elif result is not None:
    print(result)
"
  else
    echo "catalog_yq: requires yq or python3" >&2
    return 1
  fi
}

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
target_id = '$id'
field_path = '$field_path'
keys = field_path.split('.')
for entry in data.get('catalog', []):
    if entry.get('id') == target_id:
        val = entry
        for k in keys:
            if isinstance(val, dict):
                val = val.get(k)
            else:
                val = None
            if val is None:
                break
        if val is not None:
            print(val)
        break
"
}

# Print catalog ids in a named preset, one per line.
# Exits with error if the preset is not found.
catalog_resolve_preset() {
  local preset="$1"
  _catalog_python "
preset_name = '$preset'
presets = data.get('presets', {})
if preset_name not in presets:
    import sys
    print('catalog_resolve_preset: preset not found: ' + preset_name, file=sys.stderr)
    sys.exit(1)
for item_id in presets[preset_name].get('items', []):
    print(item_id)
"
}

# Read ids from stdin; print only those where <target>.available is true.
# target: cowork | claude_code
catalog_filter_by_target() {
  local target="$1"
  local id_list
  id_list="$(cat)"
  _catalog_python "
import sys
target = '$target'
id_list = '''$id_list'''.strip().splitlines()
catalog = {e['id']: e for e in data.get('catalog', [])}
for item_id in id_list:
    item_id = item_id.strip()
    if not item_id:
        continue
    entry = catalog.get(item_id, {})
    target_block = entry.get(target, {})
    if isinstance(target_block, dict) and target_block.get('available', False):
        print(item_id)
"
}

# Read ids from stdin; print only those where oauth is true.
catalog_oauth_items() {
  local id_list
  id_list="$(cat)"
  _catalog_python "
id_list = '''$id_list'''.strip().splitlines()
catalog = {e['id']: e for e in data.get('catalog', [])}
for item_id in id_list:
    item_id = item_id.strip()
    if not item_id:
        continue
    entry = catalog.get(item_id, {})
    if entry.get('oauth', False):
        print(item_id)
"
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
target_id = '$id'
for entry in data.get('catalog', []):
    if entry.get('id') == target_id:
        print('{} ({})'.format(entry.get('name','?'), entry.get('category','?')))
        break
"
}
