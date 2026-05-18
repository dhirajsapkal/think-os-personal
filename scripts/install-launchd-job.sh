#!/usr/bin/env bash
# =============================================================================
# scripts/install-launchd-job.sh — Register a Think OS cron task with launchd
# =============================================================================
# Wraps `templates/LaunchAgents/com.thinkos.cron-task.plist.template` with the
# right schedule for the requested task, writes it to
# `~/Library/LaunchAgents/com.thinkos.<task>.plist`, and `launchctl load`s it.
#
# Idempotent — re-running unloads the old plist before loading the new one.
#
# Caveat: launchd jobs only fire when the Mac is awake. Misses during sleep
# catch up on next wake (or skip, depending on the StartCalendarInterval).
#
# Usage:
#   bash scripts/install-launchd-job.sh <task-id>
#   bash scripts/install-launchd-job.sh <task-id> --dry-run
#
# Task ids (current): daily-reindex
# More to come: weekly-review, quarterly-archive, morning-brief, granola,
# calendar, clickup, gmail, slack.
# =============================================================================
set -uo pipefail

# WP-03: root guard
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "$(basename "$0"): must not be run as root. Run as your normal user account." >&2
  exit 1
fi

TASK_ID=""
DRY_RUN=0
SLACK_HANDLE=""

# Consume the first positional argument as task-id, then parse flags.
if [[ $# -ge 1 ]] && [[ "$1" != --* ]]; then
  TASK_ID="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --slack-handle)
      [[ $# -lt 2 ]] && { echo "--slack-handle requires an argument" >&2; exit 2; }
      SLACK_HANDLE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$TASK_ID" ]]; then
  echo "Usage: $0 <task-id> [--dry-run] [--slack-handle <handle>]" >&2
  exit 2
fi

# Write slack handle if provided (WP-13)
if [[ -n "$SLACK_HANDLE" ]]; then
  install -m 600 /dev/null "$HOME/.thinkos/slack-handle" 2>/dev/null || true
  printf '%s\n' "$SLACK_HANDLE" > "$HOME/.thinkos/slack-handle"
  chmod 600 "$HOME/.thinkos/slack-handle"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$REPO_ROOT/templates/LaunchAgents/com.thinkos.cron-task.plist.template"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/ThinkOS"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Template missing: $TEMPLATE" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Schedule registry — one StartCalendarInterval block per task.
#
# Each block is an XML <array> of <dict> entries (Hour/Minute/Day/Month/DoW).
# All times are LOCAL.
# -----------------------------------------------------------------------------
schedule_block_for() {
  case "$1" in
    daily-reindex)
      # 4am every day
      cat <<'XML'
<array>
  <dict><key>Hour</key><integer>4</integer><key>Minute</key><integer>0</integer></dict>
</array>
XML
      ;;
    weekly-review)
      # Sunday 8pm
      cat <<'XML'
<array>
  <dict><key>Weekday</key><integer>0</integer><key>Hour</key><integer>20</integer><key>Minute</key><integer>0</integer></dict>
</array>
XML
      ;;
    quarterly-archive)
      # First Sunday of Jan/Apr/Jul/Oct at 9pm. launchd can't express
      # "first Sunday" directly; we fire every Sunday in those months at 9pm
      # and the script checks `date +%d -le 7` itself before doing work.
      cat <<'XML'
<array>
  <dict><key>Month</key><integer>1</integer><key>Weekday</key><integer>0</integer><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Month</key><integer>4</integer><key>Weekday</key><integer>0</integer><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Month</key><integer>7</integer><key>Weekday</key><integer>0</integer><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Month</key><integer>10</integer><key>Weekday</key><integer>0</integer><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
</array>
XML
      ;;
    morning-brief)
      # 7am Mon-Fri
      cat <<'XML'
<array>
  <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>7</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Weekday</key><integer>2</integer><key>Hour</key><integer>7</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Weekday</key><integer>3</integer><key>Hour</key><integer>7</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Weekday</key><integer>4</integer><key>Hour</key><integer>7</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Weekday</key><integer>5</integer><key>Hour</key><integer>7</integer><key>Minute</key><integer>0</integer></dict>
</array>
XML
      ;;
    granola|slack)
      # Hourly (top of each hour, between 8am and 10pm to avoid overnight noise)
      cat <<'XML'
<array>
  <dict><key>Hour</key><integer>8</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>12</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>13</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>14</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>15</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>16</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>17</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>18</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>19</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>20</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Hour</key><integer>22</integer><key>Minute</key><integer>0</integer></dict>
</array>
XML
      ;;
    calendar|clickup|gmail|linear|jira)
      # Daily 6am
      cat <<'XML'
<array>
  <dict><key>Hour</key><integer>6</integer><key>Minute</key><integer>0</integer></dict>
</array>
XML
      ;;
    *)
      return 1
      ;;
  esac
}

SCHEDULE_BLOCK="$(schedule_block_for "$TASK_ID" || true)"
if [[ -z "$SCHEDULE_BLOCK" ]]; then
  echo "Unknown task id: $TASK_ID" >&2
  echo "Known: daily-reindex weekly-review quarterly-archive morning-brief granola slack calendar clickup gmail linear jira" >&2
  exit 2
fi

PLIST_PATH="$LAUNCH_AGENTS/com.thinkos.$TASK_ID.plist"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] Would write: $PLIST_PATH"
  echo "[dry-run] Schedule:"
  echo "$SCHEDULE_BLOCK"
  exit 0
fi

mkdir -p "$LAUNCH_AGENTS" "$LOG_DIR"
# WP-01: restrict log directory permissions
chmod 700 "$LOG_DIR" 2>/dev/null || true

# Render the plist via python3 (sed/awk choke on multiline replacements).
# Pass schedule via env because heredoc + multiline arg is messy.
# WP-19: XML-escape all paths before substituting into plist content.
SCHEDULE_BLOCK="$SCHEDULE_BLOCK" python3 - "$TEMPLATE" "$TASK_ID" "$REPO_ROOT" "$LOG_DIR" <<'PY' > "$PLIST_PATH"
import sys, os
from xml.sax.saxutils import escape as xml_escape
template_path, task_id, repo_root, log_dir = sys.argv[1:5]
template = open(template_path).read()
schedule_block = os.environ.get("SCHEDULE_BLOCK", "")
out = (template
       .replace("__TASK_ID__", xml_escape(task_id))
       .replace("__REPO_ROOT__", xml_escape(repo_root))
       .replace("__LOG_DIR__", xml_escape(log_dir))
       .replace("__SCHEDULE_BLOCK__", schedule_block))
sys.stdout.write(out)
PY

# Reload cleanly (unload-then-load is idempotent).
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "Installed: $PLIST_PATH"
echo "Label: com.thinkos.$TASK_ID"
echo "Logs:  $LOG_DIR/$TASK_ID.stdout.log + $LOG_DIR/$TASK_ID.stderr.log"
echo "Verify with: launchctl list | grep com.thinkos.$TASK_ID"
