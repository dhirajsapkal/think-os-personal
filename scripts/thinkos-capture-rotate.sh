#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-capture-rotate.sh — Rotate capture-log.jsonl when > 10MB
# =============================================================================
# Idempotent: if the ledger is under 10MB, exits 0 immediately.
# If over 10MB, gzip-rotates to capture-log-YYYY-MM-DD.jsonl.gz using today's
# date, then creates a fresh empty ledger.
#
# Called automatically by session-capture and external-ingest scripts before
# appending to the ledger. Can also be run manually.
#
# Usage:
#   scripts/thinkos-capture-rotate.sh [--ledger PATH] [--threshold-mb N]
#
# Flags:
#   --ledger PATH       Path to the ledger file (default: ~/.thinkos/capture-log.jsonl)
#   --threshold-mb N    Rotate when file exceeds N MB (default: 10)
#   --dry-run           Print what would happen without doing it
#   -h, --help          Show this help
# =============================================================================
set -uo pipefail

LEDGER="$HOME/.thinkos/capture-log.jsonl"
THRESHOLD_MB=10
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-capture-rotate.sh [options]

Rotates ~/.thinkos/capture-log.jsonl when it exceeds 10MB.
Gzips the current file to capture-log-YYYY-MM-DD.jsonl.gz,
then creates a fresh empty ledger.

Options:
  --ledger PATH       Ledger file path (default: ~/.thinkos/capture-log.jsonl)
  --threshold-mb N    Rotate at N MB (default: 10)
  --dry-run           Print what would happen, do nothing
  -h, --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ledger)
      LEDGER="$2"
      shift 2
      ;;
    --threshold-mb)
      THRESHOLD_MB="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
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

if ! [[ "$THRESHOLD_MB" =~ ^[0-9]+$ ]] || [[ "$THRESHOLD_MB" -lt 1 ]]; then
  echo "thinkos-capture-rotate: --threshold-mb must be a positive integer, got: $THRESHOLD_MB" >&2
  exit 2
fi

if [[ ! -f "$LEDGER" ]]; then
  # Nothing to rotate — ledger hasn't been created yet.
  exit 0
fi

LEDGER_DIR="$(dirname "$LEDGER")"
THRESHOLD_BYTES=$(( THRESHOLD_MB * 1024 * 1024 ))

# stat -f %z is macOS syntax; fall back to wc -c for portability
file_size() {
  local path="$1"
  if stat -f %z "$path" 2>/dev/null; then
    return
  fi
  # POSIX fallback
  wc -c < "$path" | tr -d ' '
}

SIZE="$(file_size "$LEDGER")"

if [[ "$SIZE" -le "$THRESHOLD_BYTES" ]]; then
  # Under threshold — nothing to do.
  exit 0
fi

TODAY="$(date -u +%Y-%m-%d)"
ARCHIVE_NAME="capture-log-${TODAY}.jsonl.gz"
ARCHIVE_PATH="$LEDGER_DIR/$ARCHIVE_NAME"

# If today's archive already exists (unlikely but possible if run twice
# in one day after a partial rotate), append a counter to the filename.
if [[ -f "$ARCHIVE_PATH" ]]; then
  COUNTER=1
  while [[ -f "$LEDGER_DIR/capture-log-${TODAY}-${COUNTER}.jsonl.gz" ]]; do
    COUNTER=$(( COUNTER + 1 ))
  done
  ARCHIVE_NAME="capture-log-${TODAY}-${COUNTER}.jsonl.gz"
  ARCHIVE_PATH="$LEDGER_DIR/$ARCHIVE_NAME"
fi

HUMAN_SIZE="$(python3 -c "s=$SIZE; print(f'{s/1024/1024:.1f} MB')")"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "dry-run: ledger is $HUMAN_SIZE (threshold: ${THRESHOLD_MB} MB)"
  echo "dry-run: would gzip $LEDGER -> $ARCHIVE_PATH"
  echo "dry-run: would create fresh empty ledger at $LEDGER"
  exit 0
fi

echo "Rotating capture ledger: $HUMAN_SIZE > ${THRESHOLD_MB} MB threshold"
echo "Archive: $ARCHIVE_PATH"

# gzip the ledger to the archive path, then truncate (not delete — avoids race
# with concurrent appenders that already have a file descriptor open).
gzip -c "$LEDGER" > "$ARCHIVE_PATH"
# Verify the archive is non-empty before wiping the source
ARCHIVE_SIZE="$(file_size "$ARCHIVE_PATH")"
if [[ "$ARCHIVE_SIZE" -lt 1 ]]; then
  echo "thinkos-capture-rotate: archive write failed (empty output); aborting rotation" >&2
  rm -f "$ARCHIVE_PATH"
  exit 1
fi

# Truncate in-place so any open file descriptors remain valid
: > "$LEDGER"

echo "Rotation complete. Archive: $ARCHIVE_NAME"
