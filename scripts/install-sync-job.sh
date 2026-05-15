#!/usr/bin/env bash
# =============================================================================
# scripts/install-sync-job.sh — Register the Think OS vault-sync launchd job
# =============================================================================
# Reads templates/LaunchAgents/com.thinkos.sync.plist.template, fills in the
# vault path and repo root, writes it to
# ~/Library/LaunchAgents/com.thinkos.sync.plist, and launchctl load's it.
#
# Idempotent — re-running unloads the old plist before loading the new one.
#
# Default schedule: Mon–Fri 18:00 local (end-of-workday). To change, edit the
# installed plist at ~/Library/LaunchAgents/com.thinkos.sync.plist and run:
#   launchctl unload ~/Library/LaunchAgents/com.thinkos.sync.plist
#   launchctl load ~/Library/LaunchAgents/com.thinkos.sync.plist
#
# Usage:
#   bash scripts/install-sync-job.sh [options]
#
# Options:
#   --vault <path>   Vault path to sync (default: resolved from vaults.json)
#   --dry-run        Preview plist content without writing or loading
#   -h, --help       Show this help
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLIST_TEMPLATE="$REPO_ROOT/templates/LaunchAgents/com.thinkos.sync.plist.template"
PLIST_LABEL="com.thinkos.sync"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
LOG_DIR="$HOME/Library/Logs/ThinkOS"

usage() {
  cat <<'EOF'
Usage: scripts/install-sync-job.sh [options]

Registers an opt-in launchd job that syncs your Think OS vault with git
every weekday at 18:00 local time (Mon–Fri). Idempotent.

Options:
  --vault <path>   Vault path to sync. Defaults to the personal hub resolved
                   from ~/.thinkos/active-vault or vaults.json.
  --dry-run        Preview the rendered plist without writing or loading it.
  -h, --help       Show this help.

After install:
  Verify with: launchctl list | grep com.thinkos.sync
  Logs:        ~/Library/Logs/ThinkOS/sync.log   (stdout)
               ~/Library/Logs/ThinkOS/sync.err   (stderr)
  Uninstall:   bash scripts/uninstall-sync-job.sh
EOF
}

VAULT_ARG=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)
      [[ $# -lt 2 ]] && { echo "--vault requires a path argument" >&2; exit 2; }
      VAULT_ARG="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2 ;;
  esac
done

# ── Platform check ────────────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "install-sync-job.sh: launchd is macOS-only." >&2
  exit 2
fi

# ── Template check ────────────────────────────────────────────────────────────
if [[ ! -f "$PLIST_TEMPLATE" ]]; then
  echo "Plist template not found: $PLIST_TEMPLATE" >&2
  exit 1
fi

# ── Vault resolution ──────────────────────────────────────────────────────────
VAULT_PATH="$VAULT_ARG"
if [[ -z "$VAULT_PATH" ]]; then
  if [[ -n "${THINKOS_VAULT:-}" ]]; then
    VAULT_PATH="$THINKOS_VAULT"
  elif [[ -f "$HOME/.thinkos/active-vault" ]]; then
    VAULT_PATH="$(cat "$HOME/.thinkos/active-vault" | tr -d '[:space:]')"
  elif [[ -f "$HOME/.thinkos/vaults.json" ]]; then
    VAULT_PATH="$(python3 -c "
import json, sys
vaults = json.load(open('$HOME/.thinkos/vaults.json'))
entries = vaults if isinstance(vaults, list) else vaults.get('vaults', [])
for v in entries:
    if v.get('default') or v.get('type') == 'personal':
        print(v.get('path', ''))
        break
" 2>/dev/null || true)"
  fi
fi

if [[ -z "$VAULT_PATH" ]]; then
  echo "Could not resolve vault path." >&2
  echo "Provide --vault <path> or set up ~/.thinkos/vaults.json." >&2
  exit 1
fi

# Expand tilde
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

# ── Render plist via python3 ──────────────────────────────────────────────────
RENDERED="$(python3 - "$PLIST_TEMPLATE" "$REPO_ROOT" "$VAULT_PATH" "$LOG_DIR" <<'PY'
import sys
tmpl_path, repo_root, vault_path, log_dir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
content = open(tmpl_path).read()
content = content.replace('__REPO_ROOT__', repo_root)
content = content.replace('__VAULT_PATH__', vault_path)
content = content.replace('__LOG_DIR__', log_dir)
sys.stdout.write(content)
PY
)"

# ── Dry run ───────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] Would write plist to: $PLIST_DEST"
  echo "[dry-run] Vault path:           $VAULT_PATH"
  echo "[dry-run] Repo root:            $REPO_ROOT"
  echo "[dry-run] Log directory:        $LOG_DIR"
  echo "[dry-run] Schedule:             Mon–Fri 18:00 local"
  echo ""
  echo "── Rendered plist ──────────────────────────────────────────────────"
  echo "$RENDERED"
  exit 0
fi

# ── Write and load ────────────────────────────────────────────────────────────
mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"

echo "$RENDERED" > "$PLIST_DEST"

# Validate the plist is well-formed before loading
if ! plutil -lint "$PLIST_DEST" >/dev/null 2>&1; then
  echo "Plist validation failed. Removing invalid file." >&2
  rm -f "$PLIST_DEST"
  exit 1
fi

# Unload-before-load for idempotency
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

echo "Installed: $PLIST_DEST"
echo "Job label: $PLIST_LABEL"
echo "Schedule:  Mon–Fri 18:00 local"
echo "Vault:     $VAULT_PATH"
echo "Stdout:    $LOG_DIR/sync.log"
echo "Stderr:    $LOG_DIR/sync.err"
echo ""
echo "Verify with: launchctl list | grep com.thinkos.sync"
echo "Uninstall:   bash scripts/uninstall-sync-job.sh"
