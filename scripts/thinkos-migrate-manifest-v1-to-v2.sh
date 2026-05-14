#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-migrate-manifest-v1-to-v2.sh
# =============================================================================
# Migrates ~/.thinkos/install-manifest.json from v1 to v2.
#
# v2 adds:
#   - thinkos_version    : git HEAD short SHA at migration time
#   - channel            : "stable" (default)
#   - repo_path          : detected from this script's location
#   - last_updated_at    : ISO8601 UTC
#   - managed_files      : array of { id, target, mode, shipped_sha, current_sha }
#   - optional_capabilities: empty array (populated by future install runs)
#
# v1 fields are preserved as-is.
#
# Idempotent: re-running on a v2 manifest is a no-op.
# Atomic: writes to a temp file then renames; backs up v1 first.
#
# Usage:
#   scripts/thinkos-migrate-manifest-v1-to-v2.sh           # apply
#   scripts/thinkos-migrate-manifest-v1-to-v2.sh --dry-run # preview, no writes
# =============================================================================

set -uo pipefail

DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '4,25p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$HOME/.thinkos/install-manifest.json"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$HOME/.thinkos/backups/$TS"

if [[ ! -f "$MANIFEST" ]]; then
  echo "No install-manifest.json at $MANIFEST. Nothing to migrate." >&2
  exit 1
fi

CURRENT_VERSION="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('version', 1))" "$MANIFEST" 2>/dev/null || echo "1")"

if [[ "$CURRENT_VERSION" != "1" ]]; then
  echo "Manifest already at v$CURRENT_VERSION. Nothing to do."
  exit 0
fi

THINKOS_VERSION="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "")"

# Run the migration through python3 (stdlib only).
TMP="$(mktemp)"
python3 - "$MANIFEST" "$THINKOS_VERSION" "$REPO_ROOT" "$TMP" <<'PY'
import json, sys, hashlib, os, glob, re
from datetime import datetime, timezone

manifest_path, thinkos_version, repo_root, tmp_out = sys.argv[1:5]
m = json.load(open(manifest_path))

def sha256_bytes(b):
    return hashlib.sha256(b).hexdigest()

def sha256_file(p):
    try:
        with open(p, "rb") as f:
            return sha256_bytes(f.read())
    except (FileNotFoundError, IsADirectoryError):
        return None

def extract_block(path, begin_marker, end_marker):
    """Return the sha of the content between BEGIN/END markers in a file.

    Returns None if file or markers are missing.
    """
    try:
        text = open(path).read()
    except FileNotFoundError:
        return None
    pattern = re.escape(begin_marker) + r"(.*?)" + re.escape(end_marker)
    match = re.search(pattern, text, re.DOTALL)
    if not match:
        return None
    return sha256_bytes(match.group(1).encode("utf-8"))

HOME = os.path.expanduser("~")

# The managed-files spec. Keep in sync with setup/manifest.yaml managed_files.
SPEC = [
    {
        "id": "claude-code-block",
        "target": f"{HOME}/.claude/CLAUDE.md",
        "mode": "block",
        "begin": "<!-- BEGIN THINK OS -->",
        "end": "<!-- END THINK OS -->",
        "products": ["claude-code"],
    },
    {
        "id": "codex-block",
        "target": f"{HOME}/.codex/AGENTS.md",
        "mode": "block",
        "begin": "<!-- BEGIN THINK OS -->",
        "end": "<!-- END THINK OS -->",
        "products": ["codex"],
    },
    {
        "id": "claude-code-commands",
        "glob": f"{HOME}/.claude/commands/thinkos-*.md",
        "mode": "file",
        "products": ["claude-code"],
    },
]

managed = []
for entry in SPEC:
    if entry["mode"] == "block":
        sha = extract_block(entry["target"], entry["begin"], entry["end"])
        if sha is None:
            # No block on disk → record entry with null shas; first update will install fresh.
            managed.append({
                "id": entry["id"],
                "target": entry["target"],
                "mode": "block",
                "shipped_sha": None,
                "current_sha": None,
                "products": entry["products"],
            })
        else:
            managed.append({
                "id": entry["id"],
                "target": entry["target"],
                "mode": "block",
                "shipped_sha": sha,
                "current_sha": sha,
                "products": entry["products"],
            })
    elif entry["mode"] == "file":
        for path in sorted(glob.glob(entry["glob"])):
            base = os.path.basename(path)
            sha = sha256_file(path)
            managed.append({
                "id": f"{entry['id']}/{base}",
                "target": path,
                "mode": "file",
                "shipped_sha": sha,
                "current_sha": sha,
                "products": entry["products"],
            })

# Build v2 manifest, preserving v1 fields
out = dict(m)
out["version"] = 2
out["thinkos_version"] = thinkos_version or ""
out["channel"] = m.get("channel", "stable")
out["repo_path"] = m.get("repo_path", repo_root)
out["last_updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
out["managed_files"] = managed
out["optional_capabilities"] = m.get("optional_capabilities", [])

# Drop the v1 "files" array — superseded by managed_files. Keep it under "files_legacy"
# in case anything still references it.
if "files" in out:
    out["files_legacy"] = out.pop("files")

with open(tmp_out, "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")

print(f"v1 entries kept: {len([k for k in m if k not in ('version',)])}")
print(f"managed_files baseline: {len(managed)} entries")
print(f"  - block entries: {sum(1 for x in managed if x['mode'] == 'block')}")
print(f"  - file entries:  {sum(1 for x in managed if x['mode'] == 'file')}")
print(f"  - with sha:      {sum(1 for x in managed if x['shipped_sha'])}")
print(f"  - missing:       {sum(1 for x in managed if not x['shipped_sha'])}")
PY

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo
  echo "[dry-run] Would back up $MANIFEST to $BACKUP_DIR/install-manifest.json"
  echo "[dry-run] Would write new v2 manifest. Diff (size):"
  echo "  v1: $(wc -c < "$MANIFEST" | tr -d ' ') bytes"
  echo "  v2: $(wc -c < "$TMP" | tr -d ' ') bytes"
  echo
  echo "Sample of new managed_files entries:"
  python3 -c "import json,sys; m=json.load(open(sys.argv[1])); print(json.dumps(m['managed_files'][:3], indent=2))" "$TMP"
  rm -f "$TMP"
  exit 0
fi

# Apply
mkdir -p "$BACKUP_DIR"
cp "$MANIFEST" "$BACKUP_DIR/install-manifest.json"
mv "$TMP" "$MANIFEST"

echo "Migrated $MANIFEST to v2."
echo "Backup: $BACKUP_DIR/install-manifest.json"
echo "thinkos_version: $THINKOS_VERSION"
