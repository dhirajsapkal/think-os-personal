#!/usr/bin/env bash
set -u
set -o pipefail

PROJECT_NAME="think-os"
OS_HOME="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
PRODUCTS=""
JSON=0
STRICT=0
DEEP=0
CHECK_BUNDLE=0

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-doctor.sh [options]

Checks whether Think OS is ready on this machine. Designed for agents to run
before setup so they can inspect state without reading or scraping the vault.

Options:
  --os-home PATH          Live Think OS vault path (default: ~/ThinkOS/vault)
  --products LIST         Comma-separated products: claude-code,all
  --json                  Print compact JSON instead of human-readable output
  --deep                  Run slower product CLI MCP checks
  --check-bundle          Compare installed plugins/connectors against the preset declared in the bundle state files
  --strict                Exit non-zero if any required check fails
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --os-home)
      OS_HOME="$2"
      shift 2
      ;;
    --products)
      PRODUCTS="$2"
      shift 2
      ;;
    --json)
      JSON=1
      shift
      ;;
    --deep)
      DEEP=1
      shift
      ;;
    --check-bundle)
      CHECK_BUNDLE=1
      shift
      ;;
    --strict)
      STRICT=1
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

if [[ "$(uname -s)" != "Darwin" ]]; then
  if [[ "$JSON" -eq 1 ]]; then
    printf '{"os_home":"%s","project":"%s","checks":[{"name":"platform","status":"fail","detail":"Think OS scripts are macOS-only for the early alpha; detected %s"}],"summary":{"ok":0,"warn":0,"fail":1}}\n' "$OS_HOME" "$PROJECT_NAME" "$(uname -s)"
  else
    echo "Think OS doctor is macOS-only for the early alpha."
    echo "Detected: $(uname -s). See docs/setup-basic-memory.md for manual setup on other platforms."
  fi
  exit 2
fi

if [[ "$PRODUCTS" == "all" ]]; then
  PRODUCTS="claude-code"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/templates"

CHECK_NAMES=()
CHECK_STATUS=()
CHECK_DETAILS=()
OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

add_check() {
  local name="$1"
  local status="$2"
  local detail="$3"
  CHECK_NAMES+=("$name")
  CHECK_STATUS+=("$status")
  CHECK_DETAILS+=("$detail")
  case "$status" in
    ok) OK_COUNT=$((OK_COUNT + 1)) ;;
    warn) WARN_COUNT=$((WARN_COUNT + 1)) ;;
    fail) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
  esac
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

has_product() {
  local needle="$1"
  [[ ",$PRODUCTS," == *",$needle,"* ]]
}

is_protected_macos_path() {
  case "$OS_HOME" in
    "$HOME/Documents"|"$HOME/Documents"/*|"$HOME/Desktop"|"$HOME/Desktop"/*|"$HOME/Downloads"|"$HOME/Downloads"/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

check_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    add_check "command:$name" ok "$(command -v "$name")"
  else
    add_check "command:$name" fail "not found"
  fi
}

run_limited_to_file() {
  local seconds="$1"
  local outfile="$2"
  shift 2

  "$@" >"$outfile" 2>&1 &
  local pid=$!

  (
    sleep "$seconds"
    kill "$pid" >/dev/null 2>&1 || true
  ) &
  local watchdog=$!

  wait "$pid" >/dev/null 2>&1
  local status=$?

  kill "$watchdog" >/dev/null 2>&1 || true
  wait "$watchdog" >/dev/null 2>&1 || true

  return "$status"
}

check_file() {
  local label="$1"
  local path="$2"
  if [[ -f "$path" ]]; then
    add_check "$label" ok "$path"
  else
    add_check "$label" fail "missing: $path"
  fi
}

add_check "repo:templates" "$([[ -d "$TEMPLATE_DIR" ]] && echo ok || echo fail)" "$TEMPLATE_DIR"

# ---------------------------------------------------------------------------
# Plugin catalog lint (scripts/lib/lint-catalog.sh)
# ---------------------------------------------------------------------------
LINT_SCRIPT="$SCRIPT_DIR/lib/lint-catalog.sh"
if [[ -f "$LINT_SCRIPT" ]]; then
  LINT_OUT="$(bash "$LINT_SCRIPT" 2>&1)"
  LINT_EXIT=$?
  LINT_DETAIL="$(printf '%s' "$LINT_OUT" | tr '\n' ' ')"
  if [[ "$LINT_EXIT" -eq 0 ]]; then
    add_check "catalog:lint" ok "data/plugin-catalog.yaml passes lint"
  elif [[ "$LINT_EXIT" -eq 1 ]]; then
    add_check "catalog:lint" fail "${LINT_DETAIL:-catalog lint reported errors}"
  else
    add_check "catalog:lint" warn "lint script exited $LINT_EXIT: ${LINT_DETAIL:-no output}"
  fi
else
  add_check "catalog:lint" warn "lint script missing: $LINT_SCRIPT"
fi

# ---------------------------------------------------------------------------
# Install manifest / version / update awareness
# ---------------------------------------------------------------------------
INSTALL_MANIFEST="$HOME/.thinkos/install-manifest.json"
if [[ -f "$INSTALL_MANIFEST" ]]; then
  MANIFEST_VERSION="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('version', 1))" "$INSTALL_MANIFEST" 2>/dev/null || echo "1")"
  THINKOS_VERSION="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('thinkos_version', ''))" "$INSTALL_MANIFEST" 2>/dev/null || echo "")"
  CHANNEL="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('channel', 'stable'))" "$INSTALL_MANIFEST" 2>/dev/null || echo "stable")"

  if [[ "$MANIFEST_VERSION" == "1" ]]; then
    add_check "install:manifest-version" warn "manifest is v1 (pre-update-protocol); first /thinkos-update will migrate to v2"
  else
    add_check "install:manifest-version" ok "v$MANIFEST_VERSION"
  fi

  if [[ -n "$THINKOS_VERSION" ]]; then
    add_check "install:version" ok "$THINKOS_VERSION ($CHANNEL)"
  else
    add_check "install:version" warn "no thinkos_version recorded (v1 manifest)"
  fi

  # Available updates — only if repo is a git checkout
  if [[ -d "$REPO_ROOT/.git" ]] && [[ -n "$THINKOS_VERSION" ]]; then
    CURRENT_HEAD="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "")"
    if [[ -n "$CURRENT_HEAD" ]] && [[ "$CURRENT_HEAD" != "$THINKOS_VERSION" ]]; then
      add_check "install:updates" warn "repo HEAD ($CURRENT_HEAD) differs from installed version ($THINKOS_VERSION); run /thinkos-update"
    elif [[ -n "$CURRENT_HEAD" ]]; then
      add_check "install:updates" ok "repo HEAD matches installed version"
    fi
  fi

  # Drift detection — count managed files whose on-disk sha differs from shipped_sha.
  # For mode=block files, sha the content BETWEEN the BEGIN/END markers (not the whole file)
  # so user-owned content outside the block doesn't register as drift.
  DRIFT_COUNT="$(python3 - "$INSTALL_MANIFEST" <<'PY' 2>/dev/null || echo "?"
import json, sys, hashlib, os, re
m = json.load(open(sys.argv[1]))
files = m.get("managed_files") or []
BEGIN = "<!-- BEGIN THINK OS -->"
END = "<!-- END THINK OS -->"
drift = 0
for f in files:
    target = f.get("target")
    shipped = f.get("shipped_sha")
    mode = f.get("mode", "file")
    if not target or not shipped or not os.path.exists(target):
        continue
    if mode == "block":
        text = open(target).read()
        pat = re.escape(BEGIN) + r"(.*?)" + re.escape(END)
        match = re.search(pat, text, re.DOTALL)
        h = hashlib.sha256(match.group(1).encode("utf-8")).hexdigest() if match else None
    else:
        h = hashlib.sha256(open(target, "rb").read()).hexdigest()
    if h and h != shipped:
        drift += 1
print(drift)
PY
)"
  if [[ "$DRIFT_COUNT" == "?" ]]; then
    add_check "install:drift" warn "drift check failed to run (python3 error reading $INSTALL_MANIFEST); drift state unknown"
  elif [[ "$DRIFT_COUNT" == "0" ]]; then
    add_check "install:drift" ok "no managed files drifted"
  else
    add_check "install:drift" warn "$DRIFT_COUNT managed file(s) edited locally; /thinkos-update will prompt before overwriting"
  fi
else
  add_check "install:manifest" warn "no install-manifest.json — Think OS may not be installed yet"
fi

if [[ -d "$OS_HOME" ]]; then
  add_check "vault:path" ok "$OS_HOME"
else
  add_check "vault:path" warn "missing; setup can create it: $OS_HOME"
fi

if [[ "$(uname -s)" == "Darwin" ]] && is_protected_macos_path; then
  add_check "vault:macos-permissions" warn "vault is under a protected macOS folder; host apps may need Files/Folders or Full Disk Access"
else
  add_check "vault:macos-permissions" ok "vault path avoids the common protected folders"
fi

for key_file in \
  "00 Home.md" \
  "01 Now/Current Focus.md" \
  "02 Projects/Project Index.md" \
  "05 Profile/Identity.md" \
  "90 System/OS Instructions.md"; do
  if [[ -f "$OS_HOME/$key_file" ]]; then
    add_check "vault:file:$key_file" ok "$OS_HOME/$key_file"
  else
    add_check "vault:file:$key_file" warn "missing from live vault"
  fi
done

check_command "uv"
check_command "basic-memory"

BM_CONFIG="$HOME/.basic-memory/config.json"
if [[ -f "$BM_CONFIG" ]]; then
  if grep -E '"mode"[[:space:]]*:[[:space:]]*"cloud"' "$BM_CONFIG" >/dev/null 2>&1; then
    add_check "basic-memory:cloud-mode" warn "one or more entries in $BM_CONFIG are cloud-mode; local-only setups should use 'basic-memory project add --local --default NAME PATH' so the project name routes around the global cloud namespace"
  else
    add_check "basic-memory:cloud-mode" ok "$BM_CONFIG has no cloud-mode entries"
  fi
else
  add_check "basic-memory:cloud-mode" ok "no Basic Memory config yet"
fi

if command -v basic-memory >/dev/null 2>&1; then
  BASIC_VERSION="$(basic-memory --version 2>/dev/null | head -n 1 || true)"
  add_check "basic-memory:version" ok "${BASIC_VERSION:-installed}"

  TMP_OUT="$(mktemp)"
  if run_limited_to_file 6 "$TMP_OUT" basic-memory project ls --name "$PROJECT_NAME"; then
    add_check "basic-memory:project" ok "$PROJECT_NAME"
    if run_limited_to_file 8 "$TMP_OUT" basic-memory tool search-notes "identity" --project "$PROJECT_NAME"; then
      add_check "basic-memory:index" ok "search-notes identity works"
    else
      add_check "basic-memory:index" warn "project exists, but search failed; run basic-memory reindex --project $PROJECT_NAME"
    fi
  else
    add_check "basic-memory:project" warn "project '$PROJECT_NAME' is not registered yet"
  fi
  rm -f "$TMP_OUT"
fi

if has_product "claude-code"; then
  check_command "claude"
  if command -v claude >/dev/null 2>&1; then
    if [[ "$DEEP" -eq 1 ]]; then
      TMP_OUT="$(mktemp)"
      if run_limited_to_file 12 "$TMP_OUT" claude mcp list && grep -q "basic-memory" "$TMP_OUT"; then
        add_check "claude-code:mcp" ok "basic-memory appears in claude mcp list"
      else
        add_check "claude-code:mcp" warn "basic-memory is not registered in Claude Code user scope, or claude mcp list timed out"
      fi
      rm -f "$TMP_OUT"
    else
      add_check "claude-code:mcp" ok "fast mode skipped CLI MCP check; run --deep to verify"
    fi
  fi
fi

# Cowork/Codex adapters cut in v0.7.0 — see roadmap/cowork-codex branch.

# ---------------------------------------------------------------------------
# Bundle checks — only when --check-bundle is set
# ---------------------------------------------------------------------------
if [[ "$CHECK_BUNDLE" -eq 1 ]]; then

  if has_product "claude-code"; then
    CC_BUNDLE_MARKER="$HOME/.thinkos/claude-code-bundle.txt"
    if [[ ! -f "$CC_BUNDLE_MARKER" ]]; then
      add_check "claude-code:bundle" ok "no bundle declared (run with --bundle to install one)"
    else
      cc_preset="$(head -n 1 "$CC_BUNDLE_MARKER" | tr -d '[:space:]')"
      if [[ -z "$cc_preset" ]]; then
        add_check "claude-code:bundle" warn "marker file exists but is empty: $CC_BUNDLE_MARKER"
      elif [[ ! "$cc_preset" =~ ^[a-z0-9_-]+$ ]]; then
        add_check "claude-code:bundle" warn "invalid preset name in $CC_BUNDLE_MARKER (only lowercase letters, digits, hyphen, underscore allowed); not resolving it"
      else
        # Source catalog and resolve expected MCP names for this preset
        # shellcheck source=scripts/lib/catalog.sh
        source "$SCRIPT_DIR/lib/catalog.sh"
        preset_ids="$(catalog_resolve_preset "$cc_preset" 2>/dev/null)" || preset_ids=""
        cc_ids="$(printf '%s\n' "$preset_ids" | catalog_filter_by_target claude_code 2>/dev/null)" || cc_ids=""

        # Collect MCP names expected for this preset
        expected_mcps=""
        while IFS= read -r pid; do
          pid="$(printf '%s' "$pid" | tr -d '[:space:]')"
          [[ -z "$pid" ]] && continue
          pkind="$(catalog_kind "$pid" "claude_code" 2>/dev/null)" || pkind=""
          if [[ "$pkind" == "mcp_remote" || "$pkind" == "mcp_stdio" ]]; then
            pmcp="$(catalog_get_field "$pid" "claude_code.mcp_name" 2>/dev/null)" || pmcp=""
            [[ -n "$pmcp" ]] && expected_mcps="${expected_mcps}${pmcp}"$'\n'
          fi
        done < <(printf '%s\n' "$cc_ids")

        if [[ -z "$(printf '%s' "$expected_mcps" | tr -d '[:space:]')" ]]; then
          # Preset has no MCP items (only plugins/skill_bundles) — skip MCP check
          add_check "claude-code:bundle" ok "preset '$cc_preset' declared; no MCP-type items to verify (plugins/skill_bundles cannot be verified from CLI in this version)"
        else
          # Run claude mcp list to verify
          TMP_MCP="$(mktemp)"
          mcp_list_ok=0
          if command -v claude >/dev/null 2>&1; then
            run_limited_to_file 12 "$TMP_MCP" claude mcp list && mcp_list_ok=1 || mcp_list_ok=0
          fi

          if [[ "$mcp_list_ok" -eq 0 ]]; then
            add_check "claude-code:bundle" fail "preset '$cc_preset' declared but 'claude mcp list' failed or claude not found"
          else
            missing_mcps=""
            while IFS= read -r mcp_name; do
              mcp_name="$(printf '%s' "$mcp_name" | tr -d '[:space:]')"
              [[ -z "$mcp_name" ]] && continue
              if ! grep -q "^${mcp_name}:" "$TMP_MCP"; then
                missing_mcps="${missing_mcps}${mcp_name} "
              fi
            done < <(printf '%s\n' "$expected_mcps")

            if [[ -n "$(printf '%s' "$missing_mcps" | tr -d '[:space:]')" ]]; then
              add_check "claude-code:bundle" warn "preset '$cc_preset': missing MCPs: ${missing_mcps% }; run thinkos-install-bundle.sh --preset $cc_preset to re-install"
            else
              add_check "claude-code:bundle" ok "preset '$cc_preset': all expected MCPs present (plugins/skill_bundles cannot be verified from CLI in this version)"
            fi
          fi
          rm -f "$TMP_MCP"
        fi
      fi
    fi
  fi

fi
# end --check-bundle

# ---------------------------------------------------------------------------
# Capture ledger checks
# ---------------------------------------------------------------------------
CAPTURE_LEDGER="$OS_HOME/90 System/Capture Log.md"

if [[ ! -f "$CAPTURE_LEDGER" ]]; then
  add_check "capture:ledger" ok "no ledger yet — will be created on first capture"
else
  # Validate: every non-empty line must be parseable JSON
  CORRUPT_LINES="$(python3 - "$CAPTURE_LEDGER" <<'PY' 2>/dev/null || echo "?"
import sys, json
bad = 0
with open(sys.argv[1]) as fh:
    for line in fh:
        line = line.strip()
        if not line or not line.startswith("{"):
            continue
        try:
            json.loads(line)
        except json.JSONDecodeError:
            bad += 1
print(bad)
PY
)"
  if [[ "$CORRUPT_LINES" == "?" ]]; then
    add_check "capture:ledger" warn "ledger validation check failed to run (python3 error); ledger state unknown: $CAPTURE_LEDGER"
  elif [[ "$CORRUPT_LINES" == "0" ]]; then
    LINE_COUNT="$(python3 -c "
import sys
n = sum(1 for l in open(sys.argv[1]) if l.strip().startswith('{'))
print(n)
" "$CAPTURE_LEDGER" 2>/dev/null || echo "?")"
    add_check "capture:ledger" ok "$LINE_COUNT event(s), all valid JSONL (vault-backed)"
  else
    add_check "capture:ledger" warn "$CORRUPT_LINES corrupt line(s) in $CAPTURE_LEDGER; run thinkos-recent.sh to see details"
  fi

  # Most recent session capture — warn if > 4h old during 9am–9pm local
  LAST_SESSION_INFO="$(python3 - "$CAPTURE_LEDGER" <<'PY' 2>/dev/null || echo ""
import sys, json, datetime

ledger = sys.argv[1]
newest_ts = None
with open(ledger) as fh:
    for line in fh:
        line = line.strip()
        if not line or not line.startswith("{"):
            continue
        try:
            evt = json.loads(line)
        except json.JSONDecodeError:
            continue
        if evt.get("source") != "session":
            continue
        ts_str = evt.get("ts", "")
        try:
            ts = datetime.datetime.fromisoformat(ts_str.rstrip("Z")).replace(tzinfo=datetime.timezone.utc)
        except (ValueError, AttributeError):
            continue
        if newest_ts is None or ts > newest_ts:
            newest_ts = ts

if newest_ts is None:
    print("none")
else:
    age_h = (datetime.datetime.now(datetime.timezone.utc) - newest_ts).total_seconds() / 3600
    print(f"{newest_ts.strftime('%Y-%m-%dT%H:%M:%SZ')} {age_h:.1f}")
PY
)"

  if [[ -z "$LAST_SESSION_INFO" || "$LAST_SESSION_INFO" == "none" ]]; then
    add_check "capture:last_session" ok "no session captures yet"
  else
    LAST_TS="$(echo "$LAST_SESSION_INFO" | awk '{print $1}')"
    AGE_H="$(echo "$LAST_SESSION_INFO" | awk '{print $2}')"
    # Check local hour to determine if we're in 9am–9pm window
    LOCAL_HOUR="$(date +%-H)"   # %H is zero-padded; bash reads "09" as bad octal
    AGE_INT="$(python3 -c "print(int(float('$AGE_H')))" 2>/dev/null || echo "0")"
    if [[ "$LOCAL_HOUR" -ge 9 && "$LOCAL_HOUR" -lt 21 && "$AGE_INT" -gt 4 ]]; then
      add_check "capture:last_session" warn "last session capture was ${AGE_H}h ago ($LAST_TS); expected every ~2h during working hours"
    else
      add_check "capture:last_session" ok "last session capture: $LAST_TS (${AGE_H}h ago)"
    fi
  fi

  # 24h event volume — warn if zero (suggests automation is stalled)
  VOLUME_24H="$(python3 - "$CAPTURE_LEDGER" <<'PY' 2>/dev/null || echo "?"
import sys, json, datetime

ledger = sys.argv[1]
cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=24)
count = 0
with open(ledger) as fh:
    for line in fh:
        line = line.strip()
        if not line or not line.startswith("{"):
            continue
        try:
            evt = json.loads(line)
        except json.JSONDecodeError:
            continue
        ts_str = evt.get("ts", "")
        try:
            ts = datetime.datetime.fromisoformat(ts_str.rstrip("Z")).replace(tzinfo=datetime.timezone.utc)
        except (ValueError, AttributeError):
            continue
        if ts >= cutoff:
            count += 1
print(count)
PY
)"
  if [[ "$VOLUME_24H" == "?" ]]; then
    add_check "capture:24h_volume" warn "24h volume check failed to run (python3 error); event volume unknown"
  elif [[ "$VOLUME_24H" == "0" ]]; then
    add_check "capture:24h_volume" warn "0 capture events in the last 24h — automation may be paused or broken"
  else
    add_check "capture:24h_volume" ok "$VOLUME_24H event(s) in last 24h"
  fi

  # Redaction count — informational only
  REDACT_COUNT="$(python3 - "$CAPTURE_LEDGER" <<'PY' 2>/dev/null || echo "0"
import sys, json

ledger = sys.argv[1]
count = 0
with open(ledger) as fh:
    for line in fh:
        line = line.strip()
        if not line or not line.startswith("{"):
            continue
        try:
            evt = json.loads(line)
        except json.JSONDecodeError:
            continue
        if evt.get("redacted") is True:
            count += 1
print(count)
PY
)"
  add_check "capture:redaction_count" ok "$REDACT_COUNT redacted event(s) in ledger (privacy routing intercepts)"
fi

# ---------------------------------------------------------------------------
# WP-37: LaunchAgent plist target-script existence check
# ---------------------------------------------------------------------------
# v0.9.11 (FIX-3): job HEALTH, not just target-script existence.
#
# The previous check only asked "does ProgramArguments[1] exist on disk?". It
# does — so doctor reported ok for all ten jobs while seven of them died on
# every run for four months. Existence is not health.
#
# Signals, in order of reliability:
#   1. Did the most recent run write to stderr? stdout gets a "=== <iso> <task> ==="
#      marker at run start; stderr only gets written on failure. If stderr's mtime
#      is at/after the last run marker, that run errored. This is ground truth.
#   2. Named signature from the stderr tail, so the report says WHY.
#   3. Staleness: no run marker within 2x the job's schedule interval.
#   4. launchctl exit status — corroborating only. It lags: a job reports its
#      PREVIOUS exit code while running, and weekly-review sat at exit=0 for days
#      while failing on every fire. Never let it decide the verdict on its own.
LAUNCHCTL_SNAPSHOT="$(launchctl list 2>/dev/null | grep 'com\.thinkos\.' || true)"

while IFS=$'\t' read -r _label _status _detail; do
  [[ -z "$_label" ]] && continue
  add_check "$_label" "$_status" "$_detail"
done < <(LAUNCHCTL_SNAPSHOT="$LAUNCHCTL_SNAPSHOT" python3 - <<'PY'
import os, glob, plistlib, time, re, calendar

snapshot = os.environ.get("LAUNCHCTL_SNAPSHOT", "")
exit_codes = {}
for line in snapshot.splitlines():
    parts = line.split()
    if len(parts) >= 3:
        exit_codes[parts[2]] = (parts[0], parts[1])   # label -> (pid, status)

SIGNATURES = [
    ("OAuth access token has expired",
     "claude's OAuth token expired — re-run /login so background jobs can authenticate"),
    ("Failed to authenticate", "claude could not authenticate — re-run /login"),
    ("claude CLI not found",   "claude not resolvable under launchd's PATH"),
    ("not found.",             "a required binary is not resolvable under launchd's PATH"),
    ("command not found",      "a required binary is missing from launchd's PATH"),
    ("Operation not permitted","macOS denied execution (stale path, or Full Disk Access needed)"),
    ("session failed",         "claude ran but exited non-zero"),
    ("missing prompt at",      "prompt file missing from scripts/cron-prompts/"),
    ("writer failed",          "the task ran but its write step failed"),
]

def emit(label, status, detail):
    print(f"{label}\t{status}\t{detail}")

def interval_seconds(pl):
    if "StartInterval" in pl:
        try:
            return int(pl["StartInterval"])
        except (TypeError, ValueError):
            pass
    cal = pl.get("StartCalendarInterval")
    if isinstance(cal, dict):
        cal = [cal]
    if isinstance(cal, list) and cal:
        # fires per day -> mean spacing. Entries with a Weekday fire weekly.
        if any("Weekday" in c for c in cal if isinstance(c, dict)):
            return 7 * 86400
        return max(1, 86400 // len(cal))
    return None

LOG_DIR = os.path.expanduser("~/Library/Logs/ThinkOS")

def task_log(label):
    """The script writes its own run log to <LOG_DIR>/<task>.log. That is NOT
    the plist's StandardOutPath (<task>.stdout.log), which only captures
    whatever leaks to stdout — usually nothing, because the scripts redirect
    into their own log. The run markers live in the former."""
    task = label.replace("com.thinkos.", "")
    cand = os.path.join(LOG_DIR, task + ".log")
    return cand if os.path.isfile(cand) else None

def last_run_start(path):
    """Epoch of the newest '=== <iso> <task> ===' marker in a run log."""
    if not path or not os.path.isfile(path):
        return None
    try:
        with open(path, "rb") as fh:
            fh.seek(0, os.SEEK_END)
            size = fh.tell()
            fh.seek(max(0, size - 65536))
            tail = fh.read().decode("utf-8", "replace")
    except OSError:
        return None
    marks = re.findall(r"^=== (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z) ", tail, re.M)
    if not marks:
        return None
    try:
        # Markers are UTC. calendar.timegm treats the struct as UTC; mktime
        # would treat it as local, and time.timezone ignores DST — that pair
        # silently shifted every timestamp by an hour during daylight time and
        # made a clean run look like a failure.
        return int(calendar.timegm(time.strptime(marks[-1], "%Y-%m-%dT%H:%M:%SZ")))
    except ValueError:
        return None

# Some scripts write progress/diagnostics to stderr on SUCCESS. Treating any
# stderr byte as failure produced a false "fail" for session-capture, whose
# filter line is informational.
BENIGN = [
    re.compile(r"^filter: \d+/\d+ (buckets|sessions) matched"),
    re.compile(r"^\[dry-run\]"),
    re.compile(r"^#"),
    re.compile(r"^\(rotated previous log"),
]

def current_run_cause(path, started, budget=32768):
    """Signature from THIS run only.

    Task logs accumulate for months. Scanning a fixed tail window surfaces
    whichever signature appears first in that window, which can be a cause
    fixed weeks ago — observed: four jobs reported as a PATH failure when the
    real, same-morning cause was an expired OAuth token. Slice to the text
    after the most recent run marker before matching."""
    if not path or not os.path.isfile(path):
        return None
    try:
        with open(path, "rb") as fh:
            fh.seek(0, os.SEEK_END)
            fh.seek(max(0, fh.tell() - budget))
            tail = fh.read().decode("utf-8", "replace")
    except OSError:
        return None
    marks = list(re.finditer(r"^=== \S+ ", tail, re.M))
    if not marks:
        # No run markers at all — this script does not write them (e.g.
        # session-capture). Without a marker we cannot tell which lines belong
        # to the current run, and matching the whole window resurrects causes
        # from months ago. Observed: a healthy session-capture reported as
        # "macOS denied execution" because of one line from a prior era.
        # Return nothing and let the caller fall back to stderr, which is
        # append-only per run and far less likely to mislead.
        return None
    tail = tail[marks[-1].start():]
    for needle, human in SIGNATURES:
        if needle in tail:
            return ("fail", human)
    return None


def stderr_cause(path, budget=8192):
    if not path or not os.path.isfile(path):
        return None
    try:
        with open(path, "rb") as fh:
            fh.seek(0, os.SEEK_END)
            fh.seek(max(0, fh.tell() - budget))
            tail = fh.read().decode("utf-8", "replace")
    except OSError:
        return None
    for needle, human in SIGNATURES:
        if needle in tail:
            return ("fail", human)
    for line in reversed([l.strip() for l in tail.splitlines() if l.strip()]):
        if any(rx.search(line) for rx in BENIGN):
            return None                      # informational, not a failure
        return ("warn", f"wrote to stderr: {line[:140]}")
    return None

now = int(time.time())
for plist_path in sorted(glob.glob(os.path.expanduser("~/Library/LaunchAgents/com.thinkos.*.plist"))):
    label = os.path.basename(plist_path)[:-6]
    try:
        with open(plist_path, "rb") as fh:
            pl = plistlib.load(fh)
    except Exception as exc:
        emit(f"launchagent:{label}", "warn", f"cannot parse plist: {exc}")
        continue

    args = pl.get("ProgramArguments") or []
    target = args[1] if len(args) > 1 else ""
    if not target:
        emit(f"launchagent:{label}", "warn",
             f"cannot read ProgramArguments[1] from {plist_path}")
        continue
    if not os.path.isfile(target):
        emit(f"launchagent:{label}", "fail", f"plist target script not found: {target}")
        continue
    emit(f"launchagent:{label}", "ok", f"plist target script exists: {target}")

    out_p, err_p = pl.get("StandardOutPath"), pl.get("StandardErrorPath")
    run_log = task_log(label)
    started = last_run_start(run_log)
    if started is None:
        # Scripts without "=== <iso> ===" markers (e.g. session-capture): fall
        # back to the newest mtime among its logs as an approximate last run.
        cands = [q for q in (run_log, out_p) if q and os.path.isfile(q)]
        if cands:
            started = int(max(os.path.getmtime(q) for q in cands))
    err_mt = os.path.getmtime(err_p) if err_p and os.path.isfile(err_p) else None
    pid, code = exit_codes.get(label, ("-", "?"))
    running = pid not in ("-", "")
    hint = f" (launchctl: pid={pid} last_exit={code}{'; currently running' if running else ''})"

    if started is None:
        found = stderr_cause(run_log) or stderr_cause(err_p)
        if found:
            emit(f"launchagent:{label}:health", found[0],
                 f"has never completed a run — {found[1]}{hint}")
        else:
            emit(f"launchagent:{label}:health", "warn",
                 f"no run log yet — job may never have fired{hint}")
        continue

    when = time.strftime("%Y-%m-%d %H:%M", time.localtime(started))
    if err_mt is not None and err_mt >= started - 2:
        # THIS run's evidence first. The task log carries claude's own message
        # (an expired OAuth token lands here); the stderr tail spans months and
        # will happily surface a cause that was fixed weeks ago.
        found = current_run_cause(run_log, started) or stderr_cause(err_p)
        if found:
            # `started` is the last run that got far enough to write a marker,
            # NOT the last attempt. A job dying before that point keeps firing
            # on schedule and keeps failing, so reporting the marker date as
            # "last run" sends the reader months away from the live problem.
            attempt = time.strftime("%Y-%m-%d %H:%M", time.localtime(err_mt))
            if attempt[:10] != when[:10]:
                msg = (f"failing — {found[1]}; last attempt {attempt}, "
                       f"last run that got started {when}")
            else:
                msg = f"last run ({when}) failed — {found[1]}"
            emit(f"launchagent:{label}:health", found[0], f"{msg}{hint}")
            continue

    iv = interval_seconds(pl)
    age = now - started
    if iv and age > 2 * iv:
        emit(f"launchagent:{label}:health", "warn",
             f"stale: last successful run {age // 3600}h ago, schedule is every "
             f"~{max(1, iv // 3600)}h{hint}")
        continue

    emit(f"launchagent:{label}:health", "ok", f"last run {when} clean{hint}")
PY
)

# v0.8.1: detect leaked LaunchAgent plist templates in the vault. These got
# copied in by setup.sh prior to v0.8.1 because copy_templates() didn't
# exclude the templates/LaunchAgents/ directory. They are not vault content;
# they are infrastructure that confuses agents inspecting the vault.
if [[ -d "$OS_HOME/LaunchAgents" ]]; then
  leaked_count=$(find "$OS_HOME/LaunchAgents" -maxdepth 1 -type f \( -name '*.plist' -o -name '*.plist.template' \) 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$leaked_count" -gt 0 ]]; then
    add_check "vault:launchagents-leaked" warn "$leaked_count plist template(s) leaked into vault at $OS_HOME/LaunchAgents/. Safe to delete (rm -rf \"$OS_HOME/LaunchAgents\") — these are infrastructure templates with unresolved tokens, not vault content. Fixed in v0.8.1 for new installs."
  fi
fi

# ---------------------------------------------------------------------------
# v0.9.11: stale local skills shadowing current commands
# ---------------------------------------------------------------------------
# This repo ships exactly three skills (adapters/claude-code/skills/). Anything
# else in ~/.claude/skills is unmanaged — /thinkos-update does not track it, so
# it never got updated when the vault moved from a flat layout to numbered
# folders in v0.8.
#
# Eleven such skills were found in the wild reading $OS_HOME/work-log.md,
# current-focus.md, active-projects.md, identity.md, business-brain.md and
# .last-touched.json — none of which exist any more. Each shadowed a working
# command of the same name, so an agent that picked the skill went hunting for
# files that were not there.
#
# Unmanaged on its own is fine: third-party skills are legitimate. The signal
# is a skill referencing the OLD vault layout.
while IFS=$'\t' read -r _name _status _detail; do
  [[ -z "$_name" ]] && continue
  add_check "$_name" "$_status" "$_detail"
done < <(REPO_ROOT="$REPO_ROOT" OS_HOME="$OS_HOME" python3 - <<'PY'
import os, re, glob

home = os.path.expanduser("~")
skills_dir = os.path.join(home, ".claude", "skills")
cmds_dir = os.path.join(home, ".claude", "commands")
repo_skills = os.path.join(os.environ.get("REPO_ROOT", ""), "adapters", "claude-code", "skills")

if not os.path.isdir(skills_dir):
    raise SystemExit(0)

# Paths that only existed before the numbered-folder vault (v0.8).
LEGACY = re.compile(
    r"\$OS_HOME/(work-log|current-focus|active-projects|decisions|people|identity|"
    r"business-brain)\.md|\$OS_HOME/\.last-touched\.json|\$OS_HOME/active-projects/"
)

stale, unmanaged = [], []
for d in sorted(glob.glob(os.path.join(skills_dir, "*", ""))):
    name = os.path.basename(d.rstrip(os.sep))
    if os.path.isdir(os.path.join(repo_skills, name)):
        continue                                   # shipped by this repo
    files = glob.glob(os.path.join(d, "*.md"))
    text = ""
    for f in files:
        try:
            text += open(f, errors="replace").read()
        except OSError:
            pass
    if LEGACY.search(text):
        shadowed = ""
        for cand in (f"{name}.md", f"thinkos-{name}.md"):
            if os.path.isfile(os.path.join(cmds_dir, cand)):
                shadowed = "/" + cand[:-3]
                break
        stale.append((name, shadowed))
    else:
        unmanaged.append(name)

if stale:
    listed = ", ".join(n + (f" (shadows {c})" if c else "") for n, c in stale)
    print("skills:stale\tfail\t%d local skill(s) reference the pre-v0.8 flat vault layout "
          "($OS_HOME/work-log.md etc.) — those files no longer exist, and an agent choosing "
          "the skill over the command will read nothing: %s. Move them aside "
          "(mv ~/.claude/skills/<name> ~/.thinkos/backups/) — the equivalent command is current."
          % (len(stale), listed))
else:
    print("skills:stale\tok\tno local skill references the retired flat vault layout")

if unmanaged:
    print("skills:unmanaged\tok\t%d unmanaged skill(s), layout-clean: %s "
          "(not shipped by this repo, so /thinkos-update will not maintain them)"
          % (len(unmanaged), ", ".join(unmanaged)))
PY
)

# ---------------------------------------------------------------------------
# v0.9.13: hook and agent vault paths.
#
# Three hooks and two agent definitions spent four months writing to the
# pre-v0.8 predecessor vault. Nothing surfaced it, because a hook that writes
# to the wrong place does not error — it succeeds, somewhere nothing reads.
#
# The logic lives in scripts/lib/check-hook-paths.py rather than inline here:
# `bash -n` does not validate heredoc contents, so a stray backtick in embedded
# Python kills every check after it while still passing a syntax check. That
# happened three times while building this one.
#
# The output is captured before the loop so an empty result is visible. A
# process substitution that dies feeds the loop nothing and reports nothing,
# which is indistinguishable from a clean pass.
# ---------------------------------------------------------------------------
HOOK_PATH_CHECKER="$REPO_ROOT/scripts/lib/check-hook-paths.py"
if [[ ! -f "$HOOK_PATH_CHECKER" ]]; then
  add_check "hooks:vault-paths" warn "checker missing: $HOOK_PATH_CHECKER"
else
  HOOK_PATH_OUT="$(python3 "$HOOK_PATH_CHECKER" "$OS_HOME" 2>/dev/null || true)"
  if [[ -z "$HOOK_PATH_OUT" ]]; then
    add_check "hooks:vault-paths" warn "hook/agent path check produced no output (python3 error); wrong-vault writers would go unnoticed"
  else
    while IFS=$'\t' read -r _name _status _detail; do
      [[ -z "$_name" ]] && continue
      add_check "$_name" "$_status" "$_detail"
    done <<<"$HOOK_PATH_OUT"
  fi
fi


# ---------------------------------------------------------------------------
# v0.9.3: focus freshness — covers_week end date vs today (mechanical, not prose)
# ---------------------------------------------------------------------------
FOCUS_FILE="$OS_HOME/01 Now/Current Focus.md"
TODAY="$(date +%Y-%m-%d)"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FOCUS_END=""
FOCUS_STATE="unknown"

if [[ ! -f "$FOCUS_FILE" ]]; then
  FOCUS_STATE="missing"
  add_check "focus:freshness" warn "Current Focus missing: $FOCUS_FILE"
else
  # covers_week from frontmatter only; end date = last YYYY-MM-DD on the line.
  # Template placeholders ({{YYYY-MM-DD}}) contain no digits -> unparseable.
  FOCUS_END="$(awk '/^---[[:space:]]*$/ { c++; next } c == 1 && /^covers_week:/ { print; exit } c >= 2 { exit }' "$FOCUS_FILE" 2>/dev/null \
    | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | tail -n 1 || true)"
  if [[ -z "$FOCUS_END" ]]; then
    FOCUS_STATE="unknown"
    add_check "focus:freshness" warn "covers_week missing or unparseable in Current Focus frontmatter (template placeholder?)"
  elif [[ "$FOCUS_END" < "$TODAY" ]]; then
    FOCUS_STATE="stale"
    add_check "focus:freshness" warn "covers_week ended $FOCUS_END (today is $TODAY); run /weekly-review"
  else
    FOCUS_STATE="fresh"
    add_check "focus:freshness" ok "covers_week current through $FOCUS_END"
  fi
fi

# Doctor (not the session hook) maintains the non-CLI freshness one-liner in
# the vault: "90 System/Focus Freshness.md". Machinery-owned, deterministic,
# safe to overwrite — one line plus minimal frontmatter.
if [[ -d "$OS_HOME/90 System" ]]; then
  FRESHNESS_NOTE="$OS_HOME/90 System/Focus Freshness.md"
  case "$FOCUS_STATE" in
    fresh) FRESHNESS_LINE="focus-fresh: YES — covers_week current through $FOCUS_END (generated_at: $NOW_ISO)" ;;
    stale) FRESHNESS_LINE="focus-fresh: NO — covers_week ended $FOCUS_END (generated_at: $NOW_ISO)" ;;
    *)     FRESHNESS_LINE="focus-fresh: UNKNOWN — covers_week missing or unparseable (generated_at: $NOW_ISO)" ;;
  esac
  if cat >"$FRESHNESS_NOTE" <<EOF
---
title: Focus Freshness
permalink: 90-system/focus-freshness
generated_at: $NOW_ISO
---
$FRESHNESS_LINE
EOF
  then
    add_check "focus:freshness-note" ok "updated $FRESHNESS_NOTE"
  else
    add_check "focus:freshness-note" warn "could not write $FRESHNESS_NOTE"
  fi
else
  add_check "focus:freshness-note" ok "skipped — no 90 System directory at $OS_HOME"
fi

# ---------------------------------------------------------------------------
# v0.9.3: index drift — Basic Memory FTS search_index vs actual table rowcounts.
# Concurrent per-session servers can race delete+insert on FTS5, leaving
# duplicate rows in search_index. /thinkos-refresh rebuilds it.
# ---------------------------------------------------------------------------
BM_DB="$HOME/.basic-memory/memory.db"
if ! command -v sqlite3 >/dev/null 2>&1; then
  add_check "index:drift" ok "sqlite3 unavailable"
elif [[ ! -f "$BM_DB" ]]; then
  add_check "index:drift" ok "no memory.db yet at $BM_DB"
else
  DRIFT_QUERY="
    SELECT
      (SELECT COUNT(*) FROM search_index WHERE type='entity'),
      (SELECT COUNT(*) FROM entity),
      (SELECT COUNT(*) FROM search_index WHERE type='observation'),
      (SELECT COUNT(*) FROM observation),
      (SELECT COUNT(*) FROM search_index WHERE type='relation'),
      (SELECT COUNT(*) FROM relation);"
  # -readonly fails on WAL-mode databases (readers need write access to the
  # -wal sidecar); fall back to a plain open, which is still SELECT-only.
  DRIFT_ROW="$(sqlite3 -readonly "$BM_DB" "$DRIFT_QUERY" 2>/dev/null || sqlite3 "$BM_DB" "$DRIFT_QUERY" 2>/dev/null || true)"
  if [[ -z "$DRIFT_ROW" ]]; then
    add_check "index:drift" ok "memory.db not queryable (locked or schema mismatch); skipped"
  else
    IFS='|' read -r SI_ENT ACT_ENT SI_OBS ACT_OBS SI_REL ACT_REL <<<"$DRIFT_ROW"
    if [[ "$SI_ENT" == "$ACT_ENT" && "$SI_OBS" == "$ACT_OBS" && "$SI_REL" == "$ACT_REL" ]]; then
      add_check "index:drift" ok "search_index matches tables (entities $ACT_ENT, observations $ACT_OBS, relations $ACT_REL)"
    else
      add_check "index:drift" warn "search_index vs actual rowcount mismatch — entities $SI_ENT/$ACT_ENT, observations $SI_OBS/$ACT_OBS, relations $SI_REL/$ACT_REL; duplicate/stale FTS rows — run /thinkos-refresh"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# v0.9.3: derived freshness — any "90 System" note carrying a generated_at
# frontmatter field older than 24h is a stale derived artifact.
# (Focus Freshness.md was just rewritten above, so it reads fresh here;
# this check covers artifacts doctor does not own.)
# ---------------------------------------------------------------------------
SYSTEM_DIR="$OS_HOME/90 System"
if [[ ! -d "$SYSTEM_DIR" ]]; then
  add_check "derived:freshness" ok "no 90 System directory yet"
else
  DERIVED_OUT="$(python3 - "$SYSTEM_DIR" <<'PY' 2>/dev/null || echo "?"
import sys, os, datetime

d = sys.argv[1]
now = datetime.datetime.now(datetime.timezone.utc)
checked = 0
stale = []
for fn in sorted(os.listdir(d)):
    if not fn.endswith(".md"):
        continue
    path = os.path.join(d, fn)
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
    except OSError:
        continue
    if not lines or lines[0].strip() != "---":
        continue
    gen = None
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if line.startswith("generated_at:"):
            gen = line.partition(":")[2].strip().strip('"').strip("'")
            break
    if gen is None:
        continue
    checked += 1
    try:
        ts = datetime.datetime.fromisoformat(gen.rstrip("Z"))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=datetime.timezone.utc)
    except ValueError:
        stale.append(f"{fn} (unparseable generated_at: {gen})")
        continue
    if (now - ts).total_seconds() > 24 * 3600:
        stale.append(f"{fn} (generated_at {gen})")
print(f"{checked}\t" + "; ".join(stale))
PY
)"
  if [[ "$DERIVED_OUT" == "?" ]]; then
    add_check "derived:freshness" warn "derived freshness check failed to run (python3 error); state unknown"
  else
    DERIVED_CHECKED="${DERIVED_OUT%%$'\t'*}"
    DERIVED_STALE="${DERIVED_OUT#*$'\t'}"
    if [[ "$DERIVED_CHECKED" == "0" ]]; then
      add_check "derived:freshness" ok "no generated_at notes under 90 System"
    elif [[ -z "$DERIVED_STALE" ]]; then
      add_check "derived:freshness" ok "$DERIVED_CHECKED generated note(s) under 90 System, all <24h old"
    else
      add_check "derived:freshness" warn "stale derived note(s) >24h old: $DERIVED_STALE"
    fi
  fi
fi

if [[ "$JSON" -eq 1 ]]; then
  printf '{"os_home":"%s","project":"%s","checks":[' "$(json_escape "$OS_HOME")" "$(json_escape "$PROJECT_NAME")"
  for i in "${!CHECK_NAMES[@]}"; do
    [[ "$i" -gt 0 ]] && printf ','
    printf '{"name":"%s","status":"%s","detail":"%s"}' \
      "$(json_escape "${CHECK_NAMES[$i]}")" \
      "$(json_escape "${CHECK_STATUS[$i]}")" \
      "$(json_escape "${CHECK_DETAILS[$i]}")"
  done
  printf '],"summary":{"ok":%d,"warn":%d,"fail":%d}}\n' "$OK_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
else
  echo "Think OS Doctor"
  echo "OS home: $OS_HOME"
  echo
  for i in "${!CHECK_NAMES[@]}"; do
    case "${CHECK_STATUS[$i]}" in
      ok) icon="OK " ;;
      warn) icon="WARN " ;;
      fail) icon="FAIL " ;;
    esac
    printf '%s %-34s %s\n' "$icon" "${CHECK_NAMES[$i]}" "${CHECK_DETAILS[$i]}"
  done
  echo
  printf 'Summary: %d ok, %d warnings, %d failures\n' "$OK_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
fi

if [[ "$STRICT" -eq 1 && "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
