#!/usr/bin/env bash
# thinkos-session-capture.sh
# Scan recent Claude Code session logs and append a work-log stub.
# Runs as a launchd cron target every 2 hours; also callable directly.
# No LLM calls. Pure bash + python3 stdlib.
set -uo pipefail

VAULT="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
THINKOS_DIR="$HOME/.thinkos"
MARKER_FILE="$THINKOS_DIR/last-session-capture"
CAPTURE_LOG="$THINKOS_DIR/capture-log.jsonl"
CLAUDE_PROJECTS_DIR="$HOME/.claude/projects"
LOOKBACK_SECONDS=7200  # 2 hours default
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-session-capture.sh [options]

Scans recent Claude Code session logs and appends a work-log stub.

Options:
  --dry-run         Print what would be written without writing anything
  --lookback Nh     Look back N hours (default: 2h)
  --vault PATH      Vault path (default: ~/ThinkOS/vault)
  -h, --help        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --lookback)
      raw="$2"
      # Accept formats like 2h, 4h, 1h
      if [[ "$raw" =~ ^([0-9]+)h$ ]]; then
        LOOKBACK_SECONDS=$(( ${BASH_REMATCH[1]} * 3600 ))
      else
        echo "Invalid --lookback value: $raw (expected Nh, e.g. 2h)" >&2
        exit 2
      fi
      shift 2
      ;;
    --vault)
      VAULT="$2"
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

# ---------------------------------------------------------------------------
# Determine cutoff time
# ---------------------------------------------------------------------------
NOW_EPOCH=$(date +%s)
CUTOFF_EPOCH=$(( NOW_EPOCH - LOOKBACK_SECONDS ))

# Read last-capture marker if present; use the later of the two as cutoff
# to prevent re-processing already-captured sessions.
if [[ -f "$MARKER_FILE" ]]; then
  MARKER_EPOCH=$(python3 -c "
import sys, datetime
raw = open(sys.argv[1]).read().strip()
try:
    dt = datetime.datetime.fromisoformat(raw.replace('Z','+00:00'))
    print(int(dt.timestamp()))
except Exception:
    print(0)
" "$MARKER_FILE" 2>/dev/null || echo 0)
  if [[ "$MARKER_EPOCH" -gt "$CUTOFF_EPOCH" ]]; then
    CUTOFF_EPOCH="$MARKER_EPOCH"
  fi
fi

# ---------------------------------------------------------------------------
# Find session files modified since cutoff
# ---------------------------------------------------------------------------
if [[ ! -d "$CLAUDE_PROJECTS_DIR" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] No Claude projects dir found at $CLAUDE_PROJECTS_DIR — nothing to capture."
  fi
  exit 0
fi

# Build list of .jsonl files newer than cutoff using python3 (portable, no GNU find -newer issues)
RECENT_FILES=$(python3 -c "
import os, sys

base = sys.argv[1]
cutoff = int(sys.argv[2])
results = []
for root, dirs, files in os.walk(base):
    for fname in files:
        if not fname.endswith('.jsonl'):
            continue
        fpath = os.path.join(root, fname)
        try:
            mtime = int(os.path.getmtime(fpath))
        except OSError:
            continue
        if mtime > cutoff:
            results.append(fpath)
for r in sorted(results):
    print(r)
" "$CLAUDE_PROJECTS_DIR" "$CUTOFF_EPOCH" 2>/dev/null)

if [[ -z "$RECENT_FILES" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] No session files modified since cutoff ($(date -r "$CUTOFF_EPOCH" 2>/dev/null || date -d "@$CUTOFF_EPOCH" 2>/dev/null || echo "epoch $CUTOFF_EPOCH")). Nothing to capture."
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Extract metadata from each session file: cwd + files touched
# ---------------------------------------------------------------------------
# Output: one JSON object per line: {"cwd": "...", "files": [...], "session_file": "..."}
SESSION_DATA=$(python3 - "$RECENT_FILES" <<'PY'
import sys, json, os

# argv[1] is newline-separated list of paths (passed as single arg via heredoc trick)
paths = [p for p in sys.argv[1].strip().split('\n') if p]

for spath in paths:
    cwd = None
    files_touched = set()
    try:
        with open(spath, 'r', errors='replace') as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue

                # Extract cwd from any entry that has it
                if cwd is None and obj.get('cwd'):
                    cwd = obj['cwd']

                # Also check message.cwd
                msg = obj.get('message') or {}
                if cwd is None and isinstance(msg, dict) and msg.get('cwd'):
                    cwd = msg['cwd']

                # Extract file paths from tool_use entries
                content = msg.get('content') if isinstance(msg, dict) else None
                if isinstance(content, list):
                    for block in content:
                        if not isinstance(block, dict):
                            continue
                        if block.get('type') != 'tool_use':
                            continue
                        tool_name = block.get('name', '')
                        if tool_name not in ('Edit', 'Write', 'MultiEdit', 'NotebookEdit'):
                            continue
                        inp = block.get('input') or {}
                        fp = inp.get('file_path') or inp.get('path') or ''
                        if fp:
                            files_touched.add(fp)
                        # MultiEdit has array of edits
                        for edit in (inp.get('edits') or []):
                            if isinstance(edit, dict):
                                ep = edit.get('file_path') or edit.get('path') or ''
                                if ep:
                                    files_touched.add(ep)
    except (OSError, IOError):
        continue

    if cwd is None:
        # Fall back: infer from project slug in the path
        # ~/.claude/projects/<slug>/<session>.jsonl
        parts = spath.split(os.sep)
        try:
            proj_idx = parts.index('projects')
            slug = parts[proj_idx + 1]
            # slug is URL-encoded path; decode naively
            import urllib.parse
            cwd = urllib.parse.unquote(slug).replace('-', '/')
            # Ensure absolute
            if not cwd.startswith('/'):
                cwd = '/' + cwd
        except (ValueError, IndexError):
            cwd = 'unknown'

    print(json.dumps({"cwd": cwd, "files": sorted(files_touched), "session_file": spath}))
PY
)

if [[ -z "$SESSION_DATA" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] Session files found but no parseable data extracted."
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Group sessions by cwd, merge file lists
# ---------------------------------------------------------------------------
# Output: one JSON object per cwd: {"cwd": "...", "files_touched": N, "session_count": N, "commit": "..."}
GROUPED=$(python3 - "$SESSION_DATA" <<'PY'
import sys, json, subprocess, os

raw = sys.argv[1].strip().split('\n')
by_cwd = {}
for line in raw:
    if not line:
        continue
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        continue
    cwd = obj.get('cwd', 'unknown')
    if cwd not in by_cwd:
        by_cwd[cwd] = {'files': set(), 'session_count': 0}
    by_cwd[cwd]['files'].update(obj.get('files', []))
    by_cwd[cwd]['session_count'] += 1

for cwd, data in sorted(by_cwd.items()):
    commit = None
    try:
        if os.path.isdir(cwd):
            result = subprocess.run(
                ['git', '-C', cwd, 'rev-parse', '--short', 'HEAD'],
                capture_output=True, text=True, timeout=3
            )
            if result.returncode == 0:
                commit = result.stdout.strip()
    except Exception:
        pass

    print(json.dumps({
        "cwd": cwd,
        "files_touched": len(data['files']),
        "session_count": data['session_count'],
        "commit": commit
    }))
PY
)

if [[ -z "$GROUPED" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Build markdown stub and write to vault
# ---------------------------------------------------------------------------
NOW_ISO=$(python3 -W ignore -c "import datetime; print(datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'))")
TODAY=$(python3 -c "import datetime; print(datetime.date.today().strftime('%Y-%m-%d'))")
TIME_HM=$(python3 -c "import datetime; print(datetime.datetime.now().strftime('%H:%M'))")

WORKLOG_REL="01 Now/Work Log.md"
WORKLOG_ABS="$VAULT/$WORKLOG_REL"

DATE_HEADER="## $TODAY"

# Build the markdown block to append
MARKDOWN=$(python3 - "$GROUPED" "$TODAY" "$TIME_HM" <<'PY'
import sys, json, os

raw_groups = sys.argv[1].strip().split('\n')
today = sys.argv[2]
time_hm = sys.argv[3]

lines = []
for line in raw_groups:
    if not line:
        continue
    try:
        g = json.loads(line)
    except json.JSONDecodeError:
        continue

    cwd = g.get('cwd', 'unknown')
    basename = os.path.basename(cwd.rstrip('/')) or cwd
    files_touched = g.get('files_touched', 0)
    session_count = g.get('session_count', 1)
    commit = g.get('commit')

    lines.append(f"\n### {time_hm} — {basename}")
    if files_touched > 0:
        lines.append(f"- Edited {files_touched} file{'s' if files_touched != 1 else ''} in `{cwd}`")
    else:
        lines.append(f"- Active in `{cwd}` (no file edits recorded)")
    if session_count > 1:
        lines.append(f"- {session_count} sessions in this directory")
    if commit:
        lines.append(f"- HEAD: `{commit}`")

print('\n'.join(lines))
PY
)

BYTES_TO_WRITE=${#MARKDOWN}

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] Would append to: $WORKLOG_ABS"
  echo "[dry-run] Date header: $DATE_HEADER"
  echo "[dry-run] Content:"
  echo "$MARKDOWN"
  echo ""
  echo "[dry-run] Would append to capture log: $CAPTURE_LOG"
  # Show one ledger line per cwd
  python3 - "$GROUPED" "$NOW_ISO" "$WORKLOG_REL" "$BYTES_TO_WRITE" <<'PY'
import sys, json, os

raw_groups = sys.argv[1].strip().split('\n')
now_iso = sys.argv[2]
output_rel = sys.argv[3]
total_bytes = int(sys.argv[4])
groups = [json.loads(l) for l in raw_groups if l.strip()]

for g in groups:
    entry = {
        "ts": now_iso,
        "source": "session",
        "detail": {
            "cwd": g.get("cwd"),
            "files_touched": g.get("files_touched", 0),
            "commit": g.get("commit"),
            "session_count": g.get("session_count", 1)
        },
        "output": output_rel,
        "mode": "append",
        "bytes": total_bytes
    }
    print("[dry-run] capture-log entry:", json.dumps(entry))
PY
  exit 0
fi

# ---------------------------------------------------------------------------
# Write to vault (live mode)
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$WORKLOG_ABS")"

# Create or update the date header section
if [[ ! -f "$WORKLOG_ABS" ]]; then
  printf '# Work Log\n\n%s\n' "$DATE_HEADER" > "$WORKLOG_ABS"
elif ! grep -qF "$DATE_HEADER" "$WORKLOG_ABS"; then
  printf '\n%s\n' "$DATE_HEADER" >> "$WORKLOG_ABS"
fi

# Append the markdown block
printf '%s\n' "$MARKDOWN" >> "$WORKLOG_ABS"

# ---------------------------------------------------------------------------
# Update marker file
# ---------------------------------------------------------------------------
mkdir -p "$THINKOS_DIR"
printf '%s\n' "$NOW_ISO" > "$MARKER_FILE"

# ---------------------------------------------------------------------------
# Append to capture ledger
# ---------------------------------------------------------------------------
python3 - "$GROUPED" "$NOW_ISO" "$WORKLOG_REL" "$BYTES_TO_WRITE" <<'PY'
import sys, json

raw_groups = sys.argv[1].strip().split('\n')
now_iso = sys.argv[2]
output_rel = sys.argv[3]
total_bytes = int(sys.argv[4])
groups = [json.loads(l) for l in raw_groups if l.strip()]

capture_log = sys.argv[5] if len(sys.argv) > 5 else None

import os
log_path = os.path.join(os.path.expanduser('~'), '.thinkos', 'capture-log.jsonl')
os.makedirs(os.path.dirname(log_path), exist_ok=True)

with open(log_path, 'a') as fh:
    for g in groups:
        entry = {
            "ts": now_iso,
            "source": "session",
            "detail": {
                "cwd": g.get("cwd"),
                "files_touched": g.get("files_touched", 0),
                "commit": g.get("commit"),
                "session_count": g.get("session_count", 1)
            },
            "output": output_rel,
            "mode": "append",
            "bytes": total_bytes
        }
        fh.write(json.dumps(entry) + '\n')
PY

exit 0
