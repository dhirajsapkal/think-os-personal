#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-vitals.sh — Vault health snapshot
# =============================================================================
# Emits a one-screen summary of vault content health:
#   - HOT file freshness (last_reviewed age, covers_week expiry)
#   - WARM file freshness (mtime-based, >30d = stale)
#   - Line counts vs. documented budgets
#   - Unreviewed autocaptures (last 30d, source != manual)
#   - Ledger volume (7d, 30d)
#   - Broken wikilinks/markdown links (HOT + 02 Projects/* only)
#   - Section ages for append-only logs (Decisions, Learnings, Work Log)
#
# Separate from thinkos-doctor.sh by design: doctor checks install/setup state;
# vitals checks vault content health. Mixing them would dilute both surfaces.
#
# Usage:
#   scripts/thinkos-vitals.sh [--os-home PATH] [--json] [-h|--help]
#
# Options:
#   --os-home PATH   Live vault path (default: $THINKOS_HOME or ~/ThinkOS/vault)
#   --json           Emit single JSON document parseable by python3 -m json.tool
#   -h, --help       Show this help
# =============================================================================
set -euo pipefail

OS_HOME="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
JSON=0

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-vitals.sh [options]

Emits a one-screen vault health snapshot (staleness, budgets, broken links,
ledger volume). This covers vault *content* health — for install/setup state
use thinkos-doctor.sh instead.

Options:
  --os-home PATH   Live vault path (default: $THINKOS_HOME or ~/ThinkOS/vault)
  --json           Emit a single JSON document (parseable by python3 -m json.tool)
  -h, --help       Show this help

Exit codes:
  0   Completed (output may still contain stale/broken items)
  2   Usage error
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --os-home)
      OS_HOME="$2"
      shift 2
      ;;
    --json)
      JSON=1
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
# Resolve vault path from vaults.json if present (same logic as doctor.sh)
# ---------------------------------------------------------------------------
VAULTS_JSON="$HOME/.thinkos/vaults.json"
if [[ -f "$VAULTS_JSON" && "$OS_HOME" == "${THINKOS_HOME:-$HOME/ThinkOS/vault}" ]]; then
  # Try to extract the personal hub (default: true) path via python3
  RESOLVED="$(python3 - "$VAULTS_JSON" <<'PY' 2>/dev/null || echo ""
import json, sys
data = json.load(open(sys.argv[1]))
vaults = data if isinstance(data, list) else data.get("vaults", [])
for v in vaults:
    if v.get("default"):
        print(v.get("path", ""))
        break
PY
)"
  if [[ -n "$RESOLVED" ]]; then
    OS_HOME="$RESOLVED"
  fi
fi

TODAY="$(date +%Y-%m-%d)"

# ---------------------------------------------------------------------------
# Helper: json_escape
# ---------------------------------------------------------------------------
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

# ---------------------------------------------------------------------------
# All heavy lifting happens in Python (stdlib only — no jq required).
# We pass vault path and today's date as argv; script prints JSON regardless
# of $JSON so we can post-process below.
# ---------------------------------------------------------------------------
VITALS_JSON="$(python3 - "$OS_HOME" "$TODAY" <<'PYEOF'
import sys, os, json, re, datetime, subprocess

vault   = sys.argv[1]
today_s = sys.argv[2]
today   = datetime.date.fromisoformat(today_s)

STUB_MARKER = "<!-- thinkos:stub -->"

# ---------------------------------------------------------------------------
# Frontmatter parser — returns dict of scalar values; stops at closing ---
# ---------------------------------------------------------------------------
def parse_frontmatter(path):
    fm = {}
    if not os.path.isfile(path):
        return fm
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
    except OSError:
        return fm
    if not lines or lines[0].strip() != "---":
        return fm
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if ":" in line:
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip()
    return fm

def is_stub(path):
    if not os.path.isfile(path):
        return False
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for i, line in enumerate(fh):
                if i > 20:
                    break
                if STUB_MARKER in line:
                    return True
    except OSError:
        pass
    return False

def file_line_count(path):
    if not os.path.isfile(path):
        return 0
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return sum(1 for _ in fh)
    except OSError:
        return 0

def parse_date(s):
    """Parse YYYY-MM-DD; return date or None."""
    if not s:
        return None
    s = s.strip().strip('"').strip("'")
    m = re.match(r"(\d{4}-\d{2}-\d{2})", s)
    if m:
        try:
            return datetime.date.fromisoformat(m.group(1))
        except ValueError:
            return None
    return None

def age_days(d):
    """Days since date d (positive = in the past)."""
    if d is None:
        return None
    return (today - d).days

def mtime_days(path):
    """Days since file mtime."""
    if not os.path.isfile(path):
        return None
    try:
        mt = os.path.getmtime(path)
        mt_date = datetime.date.fromtimestamp(mt)
        return (today - mt_date).days
    except OSError:
        return None

def parse_covers_week_end(s):
    """Parse 'YYYY-MM-DD-to-YYYY-MM-DD' → end date."""
    if not s:
        return None
    m = re.search(r"(\d{4}-\d{2}-\d{2})(?:\s*-to-\s*|\s+to\s+|\s*-\s*)(\d{4}-\d{2}-\d{2})", s)
    if m:
        return parse_date(m.group(2))
    return None

# ---------------------------------------------------------------------------
# HOT file definitions
# ---------------------------------------------------------------------------
HOT_FILES = [
    {"label": "01 Now/Current Focus.md",    "budget": 200, "has_covers_week": True},
    {"label": "02 Projects/Project Index.md","budget": 200, "has_covers_week": False},
    {"label": "05 Profile/Identity.md",      "budget": 150, "has_covers_week": False},
    {"label": "03 People/People.md",         "budget": 300, "has_covers_week": False},
]

hot_results = []
for hf in HOT_FILES:
    label = hf["label"]
    path  = os.path.join(vault, label)
    fm    = parse_frontmatter(path)
    stub  = is_stub(path)
    missing = not os.path.isfile(path)

    if missing:
        status = "missing"
        lr_age = None
        cw_exp = None
        lines  = 0
        budget = hf["budget"]
    elif stub:
        status = "stub"
        lr_age = None
        cw_exp = None
        lines  = file_line_count(path)
        budget = hf["budget"]
    else:
        lr_date = parse_date(fm.get("last_reviewed", ""))
        lr_age  = age_days(lr_date)
        cw_exp  = False
        if hf["has_covers_week"]:
            cw_end = parse_covers_week_end(fm.get("covers_week", ""))
            if cw_end is not None:
                cw_exp = (today > cw_end)
            else:
                cw_exp = None  # unparseable / template placeholder
        lines  = file_line_count(path)
        budget = int(fm.get("budget", hf["budget"])) if fm.get("budget", "").isdigit() else hf["budget"]
        # Determine status
        if lr_age is not None and lr_age > 7:
            status = "stale"
        elif cw_exp:
            status = "stale"
        else:
            status = "ok"

    entry = {
        "file": label,
        "last_reviewed_age_days": lr_age,
        "covers_week_expired": cw_exp,
        "lines": lines,
        "budget": budget,
        "status": status,
    }
    hot_results.append(entry)

# ---------------------------------------------------------------------------
# WARM file definitions (mtime-based; stale threshold = 30d)
# ---------------------------------------------------------------------------
WARM_FILES = [
    "04 Knowledge/Decisions.md",
    "04 Knowledge/Learnings.md",
    "03 People/People.md",
    "90 System/OS Instructions.md",
]

warm_results = []
for label in WARM_FILES:
    path  = os.path.join(vault, label)
    missing = not os.path.isfile(path)
    stub    = (not missing) and is_stub(path)
    mt_age  = mtime_days(path)

    if missing:
        status = "missing"
    elif stub:
        status = "stub"
    elif mt_age is not None and mt_age > 30:
        status = "stale"
    else:
        status = "ok"

    warm_results.append({
        "file": label,
        "mtime_age_days": mt_age,
        "status": status,
    })

# ---------------------------------------------------------------------------
# Unreviewed autocaptures + ledger volume
# ---------------------------------------------------------------------------
LEDGER_PATH = os.path.join(vault, "90 System", "Capture Log.md")

unreviewed_count  = 0
ledger_7d         = 0
ledger_30d        = 0
ledger_status     = "ok"

if not os.path.isfile(LEDGER_PATH):
    ledger_status = "no_ledger"
else:
    cutoff_30 = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=30)
    cutoff_7  = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=7)

    def parse_ts(ts_str):
        if not ts_str:
            return None
        try:
            return datetime.datetime.fromisoformat(ts_str.rstrip("Z")).replace(tzinfo=datetime.timezone.utc)
        except (ValueError, AttributeError):
            return None

    try:
        with open(LEDGER_PATH, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line or not line.startswith("{"):
                    continue
                try:
                    evt = json.loads(line)
                except json.JSONDecodeError:
                    continue
                ts = parse_ts(evt.get("ts", ""))
                if ts is None:
                    continue
                if ts >= cutoff_30:
                    ledger_30d += 1
                    src = evt.get("source", "manual")
                    if src != "manual" and not evt.get("reviewed"):
                        unreviewed_count += 1
                if ts >= cutoff_7:
                    ledger_7d += 1
    except OSError:
        ledger_status = "error"

# ---------------------------------------------------------------------------
# Broken links — HOT files + 02 Projects/*.md (bounded scope per spec)
# ---------------------------------------------------------------------------
SCAN_FILES = []
for hf in HOT_FILES:
    p = os.path.join(vault, hf["label"])
    if os.path.isfile(p):
        SCAN_FILES.append((hf["label"], p))

projects_dir = os.path.join(vault, "02 Projects")
if os.path.isdir(projects_dir):
    for fn in os.listdir(projects_dir):
        if fn.endswith(".md"):
            rel = os.path.join("02 Projects", fn)
            SCAN_FILES.append((rel, os.path.join(projects_dir, fn)))

WIKILINK_RE = re.compile(r"\[\[([^\]|#]+)(?:[|\]#][^\]]*)?]]")
MD_LINK_RE  = re.compile(r"\[([^\]]*)\]\(([^)]+)\)")

def resolve_wikilink(target, vault_root):
    """Check if a wikilink target exists (case-insensitive basename match)."""
    target = target.strip()
    # Strip anchors
    target = re.split(r"[#|]", target)[0].strip()
    if not target:
        return True  # empty = self-link
    # Try as a path relative to vault root
    candidate = os.path.join(vault_root, target)
    if os.path.isfile(candidate):
        return True
    if os.path.isfile(candidate + ".md"):
        return True
    # Walk vault looking for a matching filename (basename only, case-insensitive)
    want = (target.lower() + ".md").replace("/", os.sep)
    want_bare = target.lower()
    for dirpath, _dirs, files in os.walk(vault_root):
        for fn in files:
            if fn.lower() == want.split(os.sep)[-1] or fn.lower() == want_bare.split(os.sep)[-1] + ".md":
                return True
    return False

def resolve_md_link(href, from_dir, vault_root):
    """Check if a markdown link href is reachable."""
    href = href.strip()
    if href.startswith(("http://", "https://", "mailto:", "#")):
        return True  # external or anchor-only — skip
    candidate = os.path.normpath(os.path.join(from_dir, href))
    if os.path.exists(candidate):
        return True
    # Try relative to vault root
    candidate2 = os.path.join(vault_root, href)
    if os.path.exists(candidate2):
        return True
    return False

broken_links = []
for rel, abs_path in SCAN_FILES:
    from_dir = os.path.dirname(abs_path)
    try:
        content = open(abs_path, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for m in WIKILINK_RE.finditer(content):
        target = m.group(1).strip()
        if not resolve_wikilink(target, vault):
            broken_links.append({"from": rel, "to": target, "reason": "missing"})
    for m in MD_LINK_RE.finditer(content):
        href = m.group(2).strip()
        if href.startswith(("#", "http://", "https://", "mailto:")):
            continue
        if not resolve_md_link(href, from_dir, vault):
            broken_links.append({"from": rel, "to": href, "reason": "missing"})

# De-duplicate
seen = set()
unique_broken = []
for bl in broken_links:
    key = (bl["from"], bl["to"])
    if key not in seen:
        seen.add(key)
        unique_broken.append(bl)

# ---------------------------------------------------------------------------
# Section ages — Decisions, Learnings, Work Log
# ---------------------------------------------------------------------------
SECTION_LOG_FILES = [
    ("Decisions",  "04 Knowledge/Decisions.md"),
    ("Learnings",  "04 Knowledge/Learnings.md"),
    ("Work Log",   "01 Now/Work Log.md"),
]

DATE_HEADER_RE = re.compile(r"^##\s+(\d{4}-\d{2}-\d{2})")

section_ages = []
for section_name, rel_path in SECTION_LOG_FILES:
    path = os.path.join(vault, rel_path)
    if not os.path.isfile(path):
        section_ages.append({"section": section_name, "last_appended_days": None, "status": "missing"})
        continue
    try:
        content = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        section_ages.append({"section": section_name, "last_appended_days": None, "status": "error"})
        continue
    found = []
    for line in content.splitlines():
        m = DATE_HEADER_RE.match(line.strip())
        if m:
            d = parse_date(m.group(1))
            if d:
                found.append(d)
    if not found:
        section_ages.append({"section": section_name, "last_appended_days": None, "status": "no_entries"})
    else:
        most_recent = max(found)
        days = age_days(most_recent)
        section_ages.append({"section": section_name, "last_appended_days": days, "status": "ok"})

# ---------------------------------------------------------------------------
# Assemble output
# ---------------------------------------------------------------------------
try:
    output = {
        "vault": vault,
        "as_of": today_s,
        "hot_files": hot_results,
        "warm_files": warm_results,
        "unreviewed_autocaptures": unreviewed_count,
        "ledger_volume": {"7d": ledger_7d, "30d": ledger_30d},
        "ledger_status": ledger_status,
        "broken_links": unique_broken,
        "section_ages": section_ages,
    }
    print(json.dumps(output))
except Exception as e:
    print(json.dumps({"error": str(e)}))
    sys.exit(1)
PYEOF
)"

if [[ -z "$VITALS_JSON" ]]; then
  echo "vitals: no output" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if [[ "$JSON" -eq 1 ]]; then
  printf '%s\n' "$VITALS_JSON"
  exit 0
fi

# ---------------------------------------------------------------------------
# Human-readable rendering via python3
# ---------------------------------------------------------------------------
python3 - "$VITALS_JSON" <<'PYEOF'
import sys, json, textwrap

raw  = sys.argv[1]
data = json.loads(raw)

vault  = data["vault"]
as_of  = data["as_of"]

RESET  = ""  # no color codes; safe for all terminals

def status_icon(s):
    return {"ok": "OK  ", "stale": "STALE", "stub": "STUB ", "missing": "MISS ", "no_entries": "NONE ",
            "no_ledger": "NONE ", "error": "ERR  "}.get(s, "?    ")

print(f"Think OS Vitals — {as_of}")
print(f"Vault: {vault}")
print("=" * 60)

# HOT files
print("\nHOT FILES (freshness + budget)")
print(f"  {'File':<38} {'Status':<8} {'Age(d)':<8} {'Lines/Budget'}")
print(f"  {'-'*38} {'-'*7} {'-'*7} {'-'*13}")
for hf in data["hot_files"]:
    icon  = status_icon(hf["status"])
    age   = str(hf["last_reviewed_age_days"]) if hf["last_reviewed_age_days"] is not None else "—"
    lb    = f"{hf['lines']}/{hf['budget']}" if hf["lines"] else "—"
    cw    = ""
    if hf.get("covers_week_expired"):
        cw = " [week expired]"
    print(f"  {icon}  {hf['file']:<36} {age:<8} {lb}{cw}")

# WARM files
print("\nWARM FILES (mtime-based; stale > 30d)")
print(f"  {'File':<42} {'Status':<8} {'Mtime age(d)'}")
print(f"  {'-'*42} {'-'*7} {'-'*12}")
for wf in data["warm_files"]:
    icon = status_icon(wf["status"])
    age  = str(wf["mtime_age_days"]) if wf["mtime_age_days"] is not None else "—"
    print(f"  {icon}  {wf['file']:<40} {age}")

# Ledger
print("\nLEDGER")
ls = data.get("ledger_status", "ok")
print(f"  Status              : {ls}")
lv = data["ledger_volume"]
print(f"  Volume (7d / 30d)   : {lv['7d']} / {lv['30d']}")
print(f"  Unreviewed autocap  : {data['unreviewed_autocaptures']} (last 30d, source != manual)")

# Broken links
print("\nBROKEN LINKS")
bl = data["broken_links"]
if not bl:
    print("  None found in HOT + 02 Projects/*")
else:
    for item in bl:
        print(f"  {item['from']} → {item['to']}  [{item['reason']}]")

# Section ages
print("\nSECTION AGES (append-only logs)")
print(f"  {'Section':<15} {'Last appended (d ago)':<22} {'Status'}")
print(f"  {'-'*15} {'-'*21} {'-'*8}")
for sa in data["section_ages"]:
    age = str(sa["last_appended_days"]) if sa["last_appended_days"] is not None else "—"
    icon = status_icon(sa["status"])
    print(f"  {sa['section']:<15} {age:<22} {icon}")

print()
print("Run with --json for machine-readable output.")
print("Run /thinkos-vitals in Claude Code for interactive remediation.")
PYEOF
