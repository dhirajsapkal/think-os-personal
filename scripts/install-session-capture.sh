#!/usr/bin/env bash
# install-session-capture.sh
# Registers a launchd job that runs thinkos-session-capture.sh every 2 hours
# between 8am and 10pm local time. Idempotent.
set -uo pipefail

# WP-03: root guard
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "$(basename "$0"): must not be run as root. Run as your normal user account." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CAPTURE_SCRIPT="$SCRIPT_DIR/thinkos-session-capture.sh"
# WP-38: renamed template file
PLIST_TEMPLATE="$SCRIPT_DIR/../templates/LaunchAgents/com.thinkos.session-capture.plist.template"
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
# WP-01: restrict log directory permissions
chmod 700 "$LOG_DIR" 2>/dev/null || true

# WP-11/WP-38/WP-19: Build plist via Python with XML-escaped substitutions.
# xml.sax.saxutils.escape() handles &, <, > in paths. VAULT_ARG is passed via
# env to keep the shell argument list simple.
VAULT_ARG_ENV="$VAULT_ARG" python3 - "$PLIST_TEMPLATE" "$PLIST_DEST" "$CAPTURE_SCRIPT" "$LOG_DIR" "$REPO_ROOT" <<'PY'
import sys, os
from xml.sax.saxutils import escape as xml_escape

tmpl_path, dest_path, script_path, log_dir, repo_root = \
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

vault_arg = os.environ.get("VAULT_ARG_ENV", "")

# Build the optional extra ProgramArguments fragment (already XML-escaped)
if vault_arg:
    extra_args = (
        "\n    <string>--vault</string>"
        "\n    <string>" + xml_escape(vault_arg) + "</string>"
    )
else:
    extra_args = ""

content = open(tmpl_path).read()
content = content.replace('__SCRIPT_PATH__', xml_escape(script_path))
content = content.replace('__LOG_DIR__', xml_escape(log_dir))
content = content.replace('__REPO_ROOT__', xml_escape(repo_root))
content = content.replace('__EXTRA_ARGS__', extra_args)

with open(dest_path, 'w') as fh:
    fh.write(content)
PY

# WP-38: Validate plist is well-formed before loading. Abort on failure.
if ! plutil -lint "$PLIST_DEST" >/dev/null 2>&1; then
  echo "Plist validation failed (plutil -lint). Removing invalid file." >&2
  rm -f "$PLIST_DEST"
  exit 1
fi

# Reload the job (unload first in case it was already loaded)
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

echo "Installed: $PLIST_DEST"
echo "Job label: $PLIST_LABEL"
echo "Schedule: every 2 hours, 8am-10pm local time"
echo "Log output: $LOG_DIR/session-capture.log"
echo ""
echo "Verify with: launchctl list | grep thinkos.session-capture"
