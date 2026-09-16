#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-cron-run.sh — Local launchd dispatcher for Think OS cron tasks
# =============================================================================
# Invoked by a `com.thinkos.<task-id>` launchd job at its scheduled time.
# Looks up the task in the registry below, runs it, appends a ledger event,
# and exits.
#
# Two kinds of tasks:
#   deterministic — a fixed shell command (no LLM). Cheap, fast.
#   llm-prompted — invokes `claude -p "$prompt"` which spawns a one-shot
#                  Claude Code session. Costs API tokens per fire.
#
# Adding a new task = adding one case in `run_task()` below.
#
# Usage:
#   bash scripts/thinkos-cron-run.sh <task-id>          # apply
#   bash scripts/thinkos-cron-run.sh <task-id> --dry-run  # print plan, no work
#
# Exit codes:
#   0  task succeeded (or no-op)
#   1  task failed (logged)
#   2  unknown task id
# =============================================================================
set -uo pipefail
umask 0077

TASK_ID="${1:-}"
DRY_RUN=0
if [[ "${2:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ -z "$TASK_ID" ]]; then
  echo "Usage: $0 <task-id> [--dry-run]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Right model for the task — see lib/model-routing.sh for the split.
# shellcheck source=lib/model-routing.sh
source "$SCRIPT_DIR/lib/model-routing.sh"
LOG_DIR="$HOME/Library/Logs/ThinkOS"
mkdir -p "$LOG_DIR"

# ---------------------------------------------------------------------------
# Runtime PATH
# ---------------------------------------------------------------------------
# launchd runs jobs with a minimal PATH. Per-user tool installs land outside it
# — `claude` via npm-global (~/.npm-global/bin) or the native installer
# (~/.claude/local), `basic-memory` via uv (~/.local/bin). Without this, every
# job that shells out to either one dies before doing any work.
#
# Manifest first (absolute paths recorded at setup), then sweep the known
# locations so a fresh checkout recovers without re-running setup.
MANIFEST="$HOME/.thinkos/install-manifest.json"
PATH_CANDIDATES=(
  "$HOME/.npm-global/bin"
  "$HOME/.local/bin"
  "$HOME/.claude/local"
  "$HOME/.bun/bin"
  "/opt/homebrew/bin"
  "/usr/local/bin"
)

_ensure_runtime_path() {
  local dirs=() d
  if [[ -f "$MANIFEST" ]]; then
    while IFS= read -r d; do
      [[ -n "$d" ]] && dirs+=("$d")
    done < <(python3 - "$MANIFEST" 2>/dev/null <<'PY' || true
import json, os, sys
try:
    m = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for key in ("claude_bin", "basic_memory_bin"):
    p = m.get(key)
    if p and os.path.isfile(p) and os.access(p, os.X_OK):
        print(os.path.dirname(p))
PY
    )
  fi
  dirs+=("${PATH_CANDIDATES[@]}")
  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] || continue
    case ":$PATH:" in
      *":$d:"*) ;;                 # already present
      *)        PATH="$d:$PATH" ;;
    esac
  done
  export PATH
}
_ensure_runtime_path

# Names a missing binary and where we looked, instead of a bare "not found".
_report_missing_bin() {
  local bin="$1"
  {
    echo "[$TASK_ID] $bin not found."
    echo "[$TASK_ID] Searched (in order): manifest claude_bin/basic_memory_bin, then:"
    printf '[%s]   %s\n' "$TASK_ID" "${PATH_CANDIDATES[@]}"
    echo "[$TASK_ID] Fix: install $bin, or record its absolute path in $MANIFEST"
    echo "[$TASK_ID] then re-run: bash scripts/thinkos-setup.sh --record-bins"
  } >&2
}

# Resolve vault path. Personal hub by default.
VAULT="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
# Ledger lives in the vault so both shell (launchd) and basic-memory MCP
# (basic-memory MCP writers) can append to it.
LEDGER="$VAULT/90 System/Capture Log.md"
[ -f "$LEDGER" ] || { mkdir -p "$(dirname "$LEDGER")"; printf -- '---\ntitle: Capture Log\npermalink: 90-system/capture-log\n---\n\n# Capture Log\n\n' > "$LEDGER"; }

iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

ledger_append() {
  # $1 source · $2 detail-json · $3 output-path-or-null · $4 mode · $5 bytes
  local ts source detail output mode bytes line
  ts="$(iso_now)"
  source="$1"
  detail="$2"
  output="$3"
  mode="$4"
  bytes="$5"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] ledger += $source $mode"
    return
  fi
  line="$(python3 -c "
import json, sys
ts, source, detail_raw, output, mode, bytes_val = sys.argv[1:]
detail = json.loads(detail_raw)
obj = {'ts': ts, 'source': source, 'detail': detail,
       'output': None if output in ('null', '') else output,
       'mode': mode, 'bytes': int(bytes_val)}
print(json.dumps(obj))
" "$ts" "$source" "$detail" "$output" "$mode" "$bytes")"
  # Ledger entries are single-line JSON well under PIPE_BUF (4 KB), and the
  # shell opens >> with O_APPEND, so a single printf is already atomic on both
  # macOS and Linux. Do NOT reintroduce flock here: it is util-linux and does
  # not exist on macOS, where it failed on every run for four months while the
  # append silently succeeded anyway.
  printf '%s\n' "$line" >> "$LEDGER"
}

_rotate_if_large() {
  # Rotate $1 to $1.<timestamp>.bak if it exceeds 1 MB.
  local f="$1"
  [[ -f "$f" ]] || return 0
  local size
  size="$(python3 -c "import os; print(os.path.getsize('$f'))" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo 0)"
  if [[ "$size" -gt 1048576 ]]; then
    mv "$f" "${f}.$(date -u +"%Y%m%dT%H%M%SZ").bak"
  fi
}

run_deterministic() {
  # Accepts an argument array: run_deterministic cmd arg1 arg2 ...
  local logfile="$LOG_DIR/$TASK_ID.log"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would run: $*"
    echo "[dry-run] log → $logfile"
    return 0
  fi
  _rotate_if_large "$logfile"
  echo "=== $(iso_now) $TASK_ID ===" >> "$logfile"
  if "$@" >> "$logfile" 2>&1; then
    return 0
  else
    echo "[$TASK_ID] command failed; see $logfile" >&2
    return 1
  fi
}

run_llm_prompt() {
  local prompt="$1"
  local logfile="$LOG_DIR/$TASK_ID.log"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    local preview="${prompt:0:120}"
    echo "[dry-run] model: $(model_for "$TASK_ID")"
    echo "[dry-run] would run: claude -p (prompt: $preview...)"
    echo "[dry-run] log → $logfile"
    return 0
  fi
  if ! command -v claude >/dev/null 2>&1; then
    _report_missing_bin "claude CLI"
    return 1
  fi
  _rotate_if_large "$logfile"
  _rotate_if_large "${logfile%.log}.err"
  echo "=== $(iso_now) $TASK_ID ===" >> "$logfile"
  # `< /dev/null` skips claude -p's 3s "wait for stdin" warning when launchd
  # invokes us with no stdin attached.
  #
  # THINKOS_UNATTENDED marks that there is no human to confirm anything. Any
  # playbook whose interactive flow says "after the user confirms" must branch
  # on this and stage its output instead of writing. Without it, a scheduled
  # /weekly-review would either write unconfirmed or correctly decline and
  # silently do nothing — which is what left Current Focus 8 weeks stale.
  local model_args
  # shellcheck disable=SC2046  # word-splitting is intended: "" or "--model haiku"
  read -r -a model_args <<< "$(model_flag "$TASK_ID")"
  if [[ ${#model_args[@]} -gt 0 ]]; then
    echo "[model] ${model_args[*]}" >> "$logfile"
  fi
  if THINKOS_UNATTENDED=1 claude -p "${model_args[@]}" "$prompt" < /dev/null >> "$logfile" 2>&1; then
    return 0
  else
    echo "[$TASK_ID] claude session failed; see $logfile" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Task registry
# ---------------------------------------------------------------------------
# All LLM-prompted tasks read their prompt from scripts/cron-prompts/<id>.txt.
# To add a task: write its prompt to that path + add a case branch with the
# right ledger source name + register it in install-launchd-job.sh.

run_llm_task() {
  # $1 ledger source name. Reads prompt from scripts/cron-prompts/$TASK_ID.txt.
  local source="$1"
  local prompt_file="$REPO_ROOT/scripts/cron-prompts/$TASK_ID.txt"
  if [[ ! -f "$prompt_file" ]]; then
    echo "[$TASK_ID] missing prompt at $prompt_file" >&2
    return 1
  fi
  if run_llm_prompt "$(cat "$prompt_file")"; then
    # Per-item ledger events are appended by the prompt itself (for capture
    # tasks). We append a single fire-completion marker.
    ledger_append "$source" "{\"task\":\"$TASK_ID\"}" null "noop" 0
    return 0
  else
    ledger_append "$source" "{\"task\":\"$TASK_ID\",\"error\":true}" null "skipped" 0
    return 1
  fi
}

run_task() {
  case "$TASK_ID" in
    # ------------------------------------------------------------- Phase 3 maintenance
    daily-reindex)
      # Deterministic. Keeps Basic Memory's search index aligned with disk.
      # --full --search rebuilds all file-backed FTS rows. A plain incremental
      # reindex ADDS rows without purging superseded ones, so search_index drifts
      # above the entity table on every write and doctor's index:drift never
      # clears. Costs a few seconds daily; keeps search free of duplicate hits.
      if run_deterministic basic-memory reindex --project think-os --full --search; then
        ledger_append "maintenance" "{\"task\":\"daily-reindex\"}" null "noop" 0
        return 0
      else
        ledger_append "maintenance" "{\"task\":\"daily-reindex\",\"error\":true}" null "skipped" 0
        return 1
      fi
      ;;
    weekly-review|quarterly-archive|morning-brief)
      run_llm_task "maintenance"
      ;;

    # ------------------------------------------------------------- Phase C ingestion
    granola)  run_llm_task "granola"  ;;
    calendar) run_llm_task "calendar" ;;
    clickup)  run_llm_task "clickup"  ;;
    gmail)    run_llm_task "gmail"    ;;
    slack)    run_llm_task "slack"    ;;

    # Composio-backed / cross-source. Both degrade to a no-op when their
    # source is unavailable rather than failing the job.
    figma)      run_llm_task "figma"      ;;
    loose-ends) run_llm_task "loose-ends" ;;

    *)
      echo "Unknown task id: $TASK_ID" >&2
      echo "Known: daily-reindex weekly-review quarterly-archive morning-brief granola calendar clickup gmail slack figma loose-ends" >&2
      exit 2
      ;;
  esac
}

run_task
