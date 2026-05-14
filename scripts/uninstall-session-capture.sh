#!/usr/bin/env bash
# uninstall-session-capture.sh
# Removes the launchd session-capture job and its plist.
set -uo pipefail

PLIST_LABEL="com.thinkos.session-capture"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "uninstall-session-capture.sh: launchd is macOS-only." >&2
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
echo "The capture log (vault note '90 System/Capture Log.md') and marker (~/.thinkos/last-session-capture)"
echo "were NOT removed. Delete them manually if you want a clean slate."
