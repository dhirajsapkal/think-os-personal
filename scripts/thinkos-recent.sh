#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-recent.sh — Show recent capture-log events
# =============================================================================
# Default mode reads the vault note "90 System/Capture Log.md" and summarises
# events in the last N hours. Ledger metadata only — no vault content is read.
#
# --worklog mode (v0.9.3) is a deterministic, READ-ONLY date-window extraction
# of "01 Now/Work Log.md" entries from the vault file on disk. It exists so
# agents never load the full Work Log (~9.3k tokens) into context.
#
# Usage:
#   scripts/thinkos-recent.sh [--hours N] [--source X] [--json] [--redact]
#   scripts/thinkos-recent.sh --worklog [--days N] [--json]
#
# Flags:
#   --hours N      Events in the last N hours (default: 24)
#   --source X     Filter to one source (session|granola|slack|gmail|calendar|linear|clickup|manual)
#   --worklog      Extract Work Log entries instead of ledger events (read-only)
#   --days N       Worklog window in days (default: 7; only with --worklog)
#   --json         Machine-readable JSON output
#   --redact       Replace all detail values with <redacted>
#   -h, --help     Show this help
# =============================================================================
set -uo pipefail

VAULT="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
LEDGER="$VAULT/90 System/Capture Log.md"
HOURS=24
SOURCE_FILTER=""
JSON=0
REDACT=0
WORKLOG=0
DAYS=7

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-recent.sh [options]

Default mode reads the capture ledger and shows events from the last N hours.
No vault content is read — only the ledger metadata.

--worklog mode extracts dated Work Log entries from "01 Now/Work Log.md"
within the last N days (read-only; never loads the full file into context).
With --json it emits a JSON array of {date, text} objects.

Options:
  --hours N       How far back to look (default: 24)
  --source X      Filter to one source: session|granola|slack|gmail|calendar|linear|clickup|manual
  --worklog       Extract Work Log entries instead of ledger events
  --days N        Worklog window in days (default: 7; only with --worklog)
  --json          Output compact JSON
  --redact        Replace detail values with <redacted>
  -h, --help      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hours)
      HOURS="$2"
      shift 2
      ;;
    --source)
      SOURCE_FILTER="$2"
      shift 2
      ;;
    --worklog)
      WORKLOG=1
      shift
      ;;
    --days)
      DAYS="$2"
      shift 2
      ;;
    --json)
      JSON=1
      shift
      ;;
    --redact)
      REDACT=1
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

# Validate --hours is a positive integer
if ! [[ "$HOURS" =~ ^[0-9]+$ ]] || [[ "$HOURS" -lt 1 ]]; then
  echo "thinkos-recent: --hours must be a positive integer, got: $HOURS" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# --worklog mode: deterministic date-window extraction of Work Log entries.
# Read-only against the vault file on disk. Entries are markdown blocks that
# start with dated "## YYYY-MM-DD ..." or "### YYYY-MM-DD ..." headers;
# everything until the next entry header (or non-dated H2) belongs to the
# entry. Non-dated H3 headers (e.g. "### 10:41 — ...") stay in the body of
# the enclosing entry. Date arithmetic happens in python3 stdlib —
# no GNU date required (macOS bash 3.2 / BSD userland safe).
# ---------------------------------------------------------------------------
if [[ "$WORKLOG" -eq 1 ]]; then
  if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -lt 1 ]]; then
    echo "thinkos-recent: --days must be a positive integer, got: $DAYS" >&2
    exit 2
  fi

  WORKLOG_FILE="$VAULT/01 Now/Work Log.md"
  if [[ ! -f "$WORKLOG_FILE" ]]; then
    if [[ "$JSON" -eq 1 ]]; then
      printf '[]\n'
    else
      echo "No Work Log found at: $WORKLOG_FILE"
    fi
    exit 0
  fi

  python3 - "$WORKLOG_FILE" "$DAYS" "$JSON" <<'PYEOF'
import sys, json, re, datetime

path    = sys.argv[1]
days    = int(sys.argv[2])
as_json = sys.argv[3] == "1"

today  = datetime.date.today()
cutoff = today - datetime.timedelta(days=days)

# Entry headers look like "## YYYY-MM-DD HH:MM — <project-or-context>" or
# "### YYYY-MM-DD · <context>" (both header levels appear in live vaults).
# Any other "## " header (e.g. "## Entries (newest first)") terminates the
# current entry without starting a new one. Non-dated H3 headers (e.g.
# "### 10:41 — ...") are time-only sub-entries and stay in the body.
ENTRY_RE  = re.compile(r"^(##|###)\s+(\d{4}-\d{2}-\d{2})\b(.*)$")
HEADER_RE = re.compile(r"^##\s+")

entries = []
current = None

with open(path, encoding="utf-8", errors="replace") as fh:
    for raw in fh:
        line = raw.rstrip("\n")
        m = ENTRY_RE.match(line)
        if m:
            if current is not None:
                entries.append(current)
            current = {"date": m.group(2), "text": line[len(m.group(1)):].strip()}
        elif HEADER_RE.match(line):
            if current is not None:
                entries.append(current)
            current = None
        elif current is not None:
            current["text"] += "\n" + line
if current is not None:
    entries.append(current)

selected = []
for e in entries:
    try:
        d = datetime.date.fromisoformat(e["date"])
    except ValueError:
        continue
    if d >= cutoff:
        selected.append({"date": e["date"], "text": e["text"].rstrip()})

# Newest first (stable for same-day entries: file order preserved)
selected.sort(key=lambda e: e["date"], reverse=True)

if as_json:
    print(json.dumps(selected))
    sys.exit(0)

if not selected:
    print(f"No Work Log entries in the last {days} day(s).")
    sys.exit(0)

print(f"Work Log — last {days} day(s), {len(selected)} entr{'ies' if len(selected) != 1 else 'y'}")
print("─" * 46)
for e in selected:
    print(f"## {e['text']}")
    print()
PYEOF
  exit $?
fi

if [[ ! -f "$LEDGER" ]]; then
  if [[ "$JSON" -eq 1 ]]; then
    printf '{"ledger":"%s","hours":%d,"source_filter":null,"events":[],"groups":[],"message":"no captures yet"}\n' \
      "$LEDGER" "$HOURS"
  else
    echo "No captures yet. The ledger will be created when the first capture runs."
    echo "Ledger path: $LEDGER"
  fi
  exit 0
fi

# All filtering and formatting goes through python3 stdlib — no jq dependency.
REDACT_FLAG="$REDACT"
SOURCE_FILTER_VAL="$SOURCE_FILTER"

python3 - "$LEDGER" "$HOURS" "$SOURCE_FILTER_VAL" "$REDACT_FLAG" "$JSON" <<'PYEOF'
import sys, json, datetime, re

ledger_path   = sys.argv[1]
hours         = int(sys.argv[2])
source_filter = sys.argv[3]   # empty string means no filter
redact        = sys.argv[4] == "1"
as_json       = sys.argv[5] == "1"

cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=hours)

def parse_ts(ts_str):
    """Parse ISO8601 UTC string. Returns None on failure."""
    try:
        # Python 3.6 doesn't have fromisoformat with timezone, handle manually
        ts_str = ts_str.rstrip("Z")
        dt = datetime.datetime.fromisoformat(ts_str).replace(tzinfo=datetime.timezone.utc)
        return dt
    except (ValueError, AttributeError):
        return None

def redact_detail(detail):
    """Recursively replace all leaf values with '<redacted>'."""
    if isinstance(detail, dict):
        return {k: redact_detail(v) for k, v in detail.items()}
    if isinstance(detail, list):
        return [redact_detail(v) for v in detail]
    return "<redacted>"

events = []
skipped_lines = 0

with open(ledger_path) as fh:
    for lineno, raw in enumerate(fh, 1):
        raw = raw.strip()
        if not raw:
            continue
        # The ledger lives inside a markdown note; only lines that look like
        # JSON objects are events. Everything else (frontmatter, prose,
        # the "---" separator) is the human-readable header and is ignored.
        if not raw.startswith("{"):
            continue
        try:
            evt = json.loads(raw)
        except json.JSONDecodeError:
            skipped_lines += 1
            continue

        ts = parse_ts(evt.get("ts", ""))
        if ts is None or ts < cutoff:
            continue

        src = evt.get("source", "unknown")
        if source_filter and src != source_filter:
            continue

        if redact and "detail" in evt:
            evt = dict(evt)
            evt["detail"] = redact_detail(evt["detail"])

        evt["_ts_dt"] = ts
        events.append(evt)

# Sort newest-first within each group
events.sort(key=lambda e: e["_ts_dt"], reverse=True)

if as_json:
    # Strip the internal _ts_dt before output
    clean = []
    for e in events:
        c = {k: v for k, v in e.items() if k != "_ts_dt"}
        clean.append(c)
    out = {
        "ledger": ledger_path,
        "hours": hours,
        "source_filter": source_filter or None,
        "redacted": redact,
        "events": clean,
        "total": len(clean),
    }
    if skipped_lines:
        out["skipped_corrupt_lines"] = skipped_lines
    print(json.dumps(out))
    sys.exit(0)

# Human output: group by source
from collections import defaultdict, OrderedDict

groups = defaultdict(list)
for e in events:
    groups[e.get("source", "unknown")].append(e)

SOURCE_ORDER = ["session", "granola", "slack", "gmail", "calendar", "linear", "clickup", "manual"]
sorted_sources = sorted(groups.keys(), key=lambda s: SOURCE_ORDER.index(s) if s in SOURCE_ORDER else 99)

print(f"Last {hours}h")
print("\u2500" * 46)

if not events:
    if source_filter:
        print(f"No captures from source '{source_filter}' in the last {hours}h.")
    else:
        print(f"No captures in the last {hours}h.")
    if skipped_lines:
        print(f"Warning: {skipped_lines} corrupt line(s) skipped in ledger.")
    sys.exit(0)

for src in sorted_sources:
    evts = groups[src]
    count = len(evts)
    newest = evts[0]  # already sorted newest-first
    ts_str = newest["_ts_dt"].strftime("%H:%M")
    output_path = newest.get("output") or "-"
    redacted_note = "  [detail redacted]" if redact else ""
    # Truncate long output paths so the table stays readable
    if len(output_path) > 40:
        output_path = "..." + output_path[-37:]
    print(f"  {src:<12} {count:>3} capture{'s' if count != 1 else ' '} · {ts_str} · {output_path}{redacted_note}")

print()
total = len(events)
print(f"Total: {total} event{'s' if total != 1 else ''}")
if skipped_lines:
    print(f"Warning: {skipped_lines} corrupt line(s) skipped — run thinkos-doctor.sh to inspect.")
PYEOF
