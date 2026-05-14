#!/usr/bin/env bash
# install-session-capture.sh
# Registers a launchd job that runs thinkos-session-capture.sh every 2 hours
# between 8am and 10pm local time. Idempotent.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_SCRIPT="$SCRIPT_DIR/thinkos-session-capture.sh"
PLIST_TEMPLATE="$SCRIPT_DIR/../templates/LaunchAgents/com.thinkos.session-capture.plist"
PLIST_LABEL="com.thinkos.session-capture"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
LOG_DIR="$HOME/Library/Logs/ThinkOS"

usage() {
  cat <<'EOF'
Usage: scripts/install-session-capture.sh [options]

Registers a launchd job that runs the session capture script every 2 hours
between 8am and 10pm local time.

Options:
  --vault PATH    Vault path to pass to the capture script
  -h, --help      Show this help
EOF
}

VAULT_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)
      VAULT_ARG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "install-session-capture.sh: launchd is macOS-only." >&2
  exit 2
fi

if [[ ! -f "$CAPTURE_SCRIPT" ]]; then
  echo "Capture script not found: $CAPTURE_SCRIPT" >&2
  exit 1
fi

if [[ ! -f "$PLIST_TEMPLATE" ]]; then
  echo "Plist template not found: $PLIST_TEMPLATE" >&2
  exit 1
fi

chmod +x "$CAPTURE_SCRIPT"

mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$LOG_DIR"

# Build optional extra args to inject after the script path in ProgramArguments
EXTRA_ARGS=""
if [[ -n "$VAULT_ARG" ]]; then
  EXTRA_ARGS="
    <string>--vault</string>
    <string>$VAULT_ARG</string>"
fi

# Replace placeholders in template and write to destination.
# Use python3 to avoid BSD sed's inability to handle multi-line replacements.
python3 - "$PLIST_TEMPLATE" "$PLIST_DEST" "$CAPTURE_SCRIPT" "$LOG_DIR" "$EXTRA_ARGS" <<'PY'
import sys

tmpl_path, dest_path, script_path, log_dir, extra_args = \
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

content = open(tmpl_path).read()
content = content.replace('__SCRIPT_PATH__', script_path)
content = content.replace('__LOG_DIR__', log_dir)
content = content.replace('__EXTRA_ARGS__', extra_args)

with open(dest_path, 'w') as fh:
    fh.write(content)
PY

# Reload the job (unload first in case it was already loaded)
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

echo "Installed: $PLIST_DEST"
echo "Job label: $PLIST_LABEL"
echo "Schedule: every 2 hours, 8am-10pm local time"
echo "Log output: $LOG_DIR/session-capture.log"
echo ""
echo "Verify with: launchctl list | grep thinkos.session-capture"
