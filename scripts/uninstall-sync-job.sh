#!/usr/bin/env bash
# =============================================================================
# scripts/uninstall-sync-job.sh — Remove the Think OS vault-sync launchd job
# =============================================================================
# Unloads com.thinkos.sync from launchd and removes the plist from
# ~/Library/LaunchAgents/. Logs and vault contents are NOT removed.
#
# Usage:
#   bash scripts/uninstall-sync-job.sh [-h|--help]
# =============================================================================
set -uo pipefail

PLIST_LABEL="com.thinkos.sync"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

usage() {
  cat <<'EOF'
Usage: scripts/uninstall-sync-job.sh [-h|--help]

Removes the Think OS vault-sync launchd job (com.thinkos.sync).

The sync logs at ~/Library/Logs/ThinkOS/sync.log and sync.err are NOT removed.
The vault itself is NOT touched.

To reinstall later: bash scripts/install-sync-job.sh
EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "uninstall-sync-job.sh: launchd is macOS-only." >&2
  exit 2
fi

if [[ ! -f "$PLIST_DEST" ]]; then
  echo "Plist not found at $PLIST_DEST — nothing to uninstall."
  exit 0
fi

launchctl unload "$PLIST_DEST" 2>/dev/null || true
rm -f "$PLIST_DEST"

echo "Uninstalled: $PLIST_LABEL"
echo "Plist removed: $PLIST_DEST"
echo ""
echo "Sync logs (~/Library/Logs/ThinkOS/sync.log, sync.err) were NOT removed."
echo "To reinstall: bash scripts/install-sync-job.sh"
