#!/usr/bin/env bash
# thinkos-session-capture.sh
# Scan recent Claude Code session logs and append a work-log stub.
# Runs as a launchd cron target every 2 hours; also callable directly.
# No LLM calls. Pure bash + python3 stdlib.
set -uo pipefail
umask 0077

VAULT="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
THINKOS_DIR="$HOME/.thinkos"
MARKER_FILE="$THINKOS_DIR/last-session-capture"
LOG_DIR="$HOME/Library/Logs/ThinkOS"
CLAUDE_PROJECTS_DIR="$HOME/.claude/projects"
LOOKBACK_SECONDS=7200  # 2 hours default
DRY_RUN=0
ALL_PROJECTS=0  # when 1, skip vault-path filtering (--all-projects flag)

# ---------------------------------------------------------------------------
# Resolve vault path from active-vault override, vaults.json default, fallback
# ---------------------------------------------------------------------------
_resolve_vault() {
  local active_file="$THINKOS_DIR/active-vault"
  local vaults_json="$THINKOS_DIR/vaults.json"
  if [[ -f "$active_file" ]]; then
    local vault_id
    vault_id="$(tr -d '[:space:]' < "$active_file")"
    if [[ -n "$vault_id" && -f "$vaults_json" ]]; then
      local resolved
      resolved=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
for v in d.get('vaults', []):
    if v.get('id') == sys.argv[2]:
        print(v.get('path',''))
        sys.exit(0)
" "$vaults_json" "$vault_id" 2>/dev/null || true)
      if [[ -n "$resolved" ]]; then
        echo "$resolved"
        return
      fi
    fi
  fi
  if [[ -f "$vaults_json" ]]; then
    local default_path
    default_path=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
for v in d.get('vaults', []):
    if v.get('default'):
        print(v.get('path',''))
        sys.exit(0)
" "$vaults_json" 2>/dev/null || true)
    if [[ -n "$default_path" ]]; then
      echo "$default_path"
      return
    fi
  fi
  echo "${THINKOS_HOME:-$HOME/ThinkOS/vault}"
}

VAULT="$(_resolve_vault)"
# Ledger lives in the vault so both shell (this script) and basic-memory MCP
# (Cowork scheduled tasks) can append to it.
LEDGER="$VAULT/90 System/Capture Log.md"

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-session-capture.sh [options]

Scans recent Claude Code session logs and appends a work-log stub.

Options:
  --dry-run         Print what would be written without writing anything
  --lookback Nh     Look back N hours (default: 2h)
  --vault PATH      Vault path (default: resolved from ~/.thinkos/active-vault)
  --all-projects    Capture sessions from ALL cwd paths, not just registered paths
  -h, --help        Show this help

By default, only sessions whose cwd is under a registered Think OS path are
captured. The allowed list is the union of vault paths and tracked_projects
entries in ~/.thinkos/vaults.json. Use --all-projects to disable this filter.
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
      # Note: BASH_REMATCH requires bash 3.2+ (standard on macOS since 10.5).
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
      LEDGER="$VAULT/90 System/Capture Log.md"
      shift 2
      ;;
    --all-projects)
      ALL_PROJECTS=1
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

# ---------------------------------------------------------------------------
# Log rotation (rotate session-capture.log/.err if >1MB before each run)
# ---------------------------------------------------------------------------
_rotate_if_large() {
  local f="$1"
  [ -f "$f" ] || return 0
  local size; size=$(stat -f %z "$f" 2>/dev/null || echo 0)
  if [ "$size" -gt 1048576 ]; then  # 1MB cap
    mv "$f" "${f}.1"
    echo "(rotated previous log at $(date)) ===" > "$f"
  fi
}

mkdir -p "$LOG_DIR"
_rotate_if_large "$LOG_DIR/session-capture.log"
_rotate_if_large "$LOG_DIR/session-capture.err"

# Ensure ledger file exists with proper header
[ -f "$LEDGER" ] || { mkdir -p "$(dirname "$LEDGER")"; printf -- '---\ntitle: Capture Log\npermalink: 90-system/capture-log\n---\n\n# Capture Log\n\n' > "$LEDGER"; }

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
# Extract activity since cutoff
# ---------------------------------------------------------------------------
# Delegated to scripts/session-activity.py, which filters by each JSONL entry's
# OWN `timestamp`. Do not go back to selecting files by mtime and parsing them
# whole: a session file can span many days, so that approach re-reported every
# historical edit on every run and invented activity on days with none.
# ---------------------------------------------------------------------------
if [[ ! -d "$CLAUDE_PROJECTS_DIR" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] No Claude projects dir found at $CLAUDE_PROJECTS_DIR — nothing to capture."
  fi
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTIVITY_PY="$SCRIPT_DIR/session-activity.py"
if [[ ! -f "$ACTIVITY_PY" ]]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] thinkos-session-capture: missing $ACTIVITY_PY" >&2
  exit 1
fi

# Ask the analyzer for per-(project, day) activity since the cutoff.
ACTIVITY_JSON=$(python3 "$ACTIVITY_PY" --since-epoch "$CUTOFF_EPOCH" --format json 2>/dev/null)

if [[ -z "$ACTIVITY_JSON" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] Analyzer returned nothing. Nothing to capture."
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Filter to registered paths (unless --all-projects) and flatten to one JSON
# object per (cwd, date). Allowed list = vaults[].path ∪ tracked_projects[].path
# ---------------------------------------------------------------------------
GROUPED=$(python3 - "$ACTIVITY_JSON" "$THINKOS_DIR/vaults.json" "$ALL_PROJECTS" <<'PYEOF'
import sys, json, os

payload = json.loads(sys.argv[1])
vaults_json = sys.argv[2]
all_projects = sys.argv[3] == "1"

allowed = []
if not all_projects and os.path.isfile(vaults_json):
    try:
        data = json.load(open(vaults_json))
        for v in data.get("vaults", []):
            if v.get("path"):
                allowed.append(os.path.realpath(os.path.expanduser(v["path"])))
        for tp in data.get("tracked_projects", []):
            if tp.get("path"):
                allowed.append(os.path.realpath(os.path.expanduser(tp["path"])))
    except Exception:
        pass

def ok(cwd):
    if all_projects or not allowed:
        return True
    try:
        real = os.path.realpath(os.path.expanduser(cwd))
    except Exception:
        return False
    return any(real == a or real.startswith(a + os.sep) for a in allowed)

buckets = payload.get("buckets", [])
kept = [b for b in buckets if ok(b.get("cwd", ""))]
for b in kept:
    print(json.dumps(b))
print(f"filter: {len(kept)}/{len(buckets)} buckets matched "
      f"({len(allowed)} allowed paths)", file=sys.stderr)
PYEOF
)

if [[ -z "$GROUPED" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Render + write. Done entirely in python3 so each bucket lands under its OWN
# date header (a 2h window can straddle midnight) and so dry-run and live share
# one code path.
# ---------------------------------------------------------------------------
NOW_ISO=$(python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))")
WORKLOG_REL="01 Now/Work Log.md"
WORKLOG_ABS="$VAULT/$WORKLOG_REL"

python3 - "$GROUPED" "$WORKLOG_ABS" "$WORKLOG_REL" "$LEDGER" "$NOW_ISO" "$DRY_RUN" <<'PYEOF'
import sys, json, os, re

raw, worklog, worklog_rel, ledger, now_iso, dry = sys.argv[1:7]
dry = dry == "1"

buckets = []
for line in raw.strip().split("\n"):
    line = line.strip()
    if not line:
        continue
    try:
        buckets.append(json.loads(line))
    except json.JSONDecodeError:
        continue
if not buckets:
    sys.exit(0)

def render(b):
    out = [f"\n### {b['first']}–{b['last']} — {b['project']} · {b['active_hours']:.2f}h"]
    loc = f"- `{b['cwd']}`"
    if b.get("branch"):
        loc += f" · branch `{b['branch']}`"
    out.append(loc)
    if b.get("edit_calls"):
        out.append(f"- {b['edit_calls']} edit call"
                   f"{'s' if b['edit_calls'] != 1 else ''} across "
                   f"{b['file_count']} file{'s' if b['file_count'] != 1 else ''}")
        names = [os.path.basename(f) for f in b.get("files", [])[:4]]
        extra = b["file_count"] - len(names)
        if names:
            out.append("- Files: " + ", ".join(f"`{n}`" for n in names)
                       + (f" (+{extra})" if extra > 0 else ""))
    else:
        out.append(f"- {b['events']} events, no file edits recorded")
    return "\n".join(out)

by_date = {}
for b in sorted(buckets, key=lambda x: (x["date"], x["first"])):
    by_date.setdefault(b["date"], []).append(render(b))

total_bytes = sum(len(t) for blocks in by_date.values() for t in blocks)

if dry:
    print(f"[dry-run] Would append to: {worklog}")
    for date, blocks in sorted(by_date.items()):
        print(f"[dry-run] under header: ## {date}")
        for blk in blocks:
            print(blk)
    print()
    print(f"[dry-run] Would append {len(buckets)} ledger line(s) to: {ledger}")

if not dry:
    os.makedirs(os.path.dirname(worklog), exist_ok=True)
    body = open(worklog).read() if os.path.exists(worklog) else "# Work Log\n"
    for date, blocks in sorted(by_date.items()):
        header = f"## {date}"
        chunk = "\n".join(blocks) + "\n"
        # Insert under an existing header for that date, else append a new one.
        m = re.search(rf"^{re.escape(header)}\s*$", body, re.M)
        if m:
            nxt = re.search(r"^## \d{4}-\d{2}-\d{2}\s*$", body[m.end():], re.M)
            cut = m.end() + (nxt.start() if nxt else len(body) - m.end())
            body = body[:cut].rstrip("\n") + "\n" + chunk + body[cut:]
        else:
            body = body.rstrip("\n") + f"\n\n{header}\n{chunk}"
    with open(worklog, "w") as fh:
        fh.write(body)

lines = []
for b in buckets:
    lines.append(json.dumps({
        "ts": now_iso,
        "source": "session",
        "detail": {
            "cwd": b["cwd"], "project": b["project"], "date": b["date"],
            "first": b["first"], "last": b["last"],
            "active_hours": b["active_hours"], "events": b["events"],
            "edit_calls": b["edit_calls"], "file_count": b["file_count"],
            "files": b.get("files", [])[:20], "branch": b.get("branch"),
        },
        "output": worklog_rel, "mode": "append", "bytes": total_bytes,
    }))

if dry:
    for l in lines:
        print("[dry-run] ledger entry:", l)
else:
    # A previous writer may have left the file without a terminal newline;
    # appending blind would glue our first event onto theirs and make both
    # unparseable. See the matching guard in thinkos-cron-run.sh.
    need_nl = False
    try:
        with open(ledger, "rb") as fh:
            fh.seek(0, 2)
            if fh.tell():
                fh.seek(-1, 2)
                need_nl = fh.read(1) != b"\n"
    except FileNotFoundError:
        pass
    with open(ledger, "a") as fh:
        fh.write(("\n" if need_nl else "") + "\n".join(lines) + "\n")
    print(f"captured {len(buckets)} bucket(s), "
          f"{sum(b['active_hours'] for b in buckets):.2f}h active")
PYEOF
RC=$?

if [[ "$DRY_RUN" -eq 1 ]]; then
  exit "$RC"
fi
if [[ "$RC" -ne 0 ]]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] thinkos-session-capture: writer failed (rc=$RC)" >&2
  exit "$RC"
fi

# Advance the marker only after a successful write.
mkdir -p "$THINKOS_DIR"
printf '%s\n' "$NOW_ISO" > "$MARKER_FILE"

exit 0
