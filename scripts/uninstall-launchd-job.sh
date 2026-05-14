#!/usr/bin/env bash
# =============================================================================
# scripts/uninstall-launchd-job.sh — Remove a Think OS launchd cron task
# =============================================================================
# Companion to install-launchd-job.sh. Unloads + deletes the plist.
# Idempotent — silent on already-uninstalled tasks.
#
# Usage:
#   bash scripts/uninstall-launchd-job.sh <task-id>
# =============================================================================
set -uo pipefail

TASK_ID="${1:-}"
if [[ -z "$TASK_ID" ]]; then
  echo "Usage: $0 <task-id>" >&2
  exit 2
fi

PLIST_PATH="$HOME/Library/LaunchAgents/com.thinkos.$TASK_ID.plist"

if [[ ! -f "$PLIST_PATH" ]]; then
  echo "Not installed: $PLIST_PATH"
  exit 0
fi

launchctl unload "$PLIST_PATH" 2>/dev/null || true
rm -f "$PLIST_PATH"
echo "Removed: $PLIST_PATH"
