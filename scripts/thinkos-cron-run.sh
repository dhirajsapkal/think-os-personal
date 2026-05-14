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
LEDGER="$HOME/.thinkos/capture-log.jsonl"
LOG_DIR="$HOME/Library/Logs/ThinkOS"
mkdir -p "$LOG_DIR" "$(dirname "$LEDGER")"

# Resolve vault path. Personal hub by default.
VAULT="${THINKOS_HOME:-$HOME/ThinkOS/vault}"

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
  if [[ "$output" == "null" || -z "$output" ]]; then
    line="{\"ts\":\"$ts\",\"source\":\"$source\",\"detail\":$detail,\"output\":null,\"mode\":\"$mode\",\"bytes\":$bytes}"
  else
    line="{\"ts\":\"$ts\",\"source\":\"$source\",\"detail\":$detail,\"output\":\"$output\",\"mode\":\"$mode\",\"bytes\":$bytes}"
  fi
  printf '%s\n' "$line" >> "$LEDGER"
}

run_deterministic() {
  local cmd="$1"
  local logfile="$LOG_DIR/$TASK_ID.log"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would run: $cmd"
    echo "[dry-run] log → $logfile"
    return 0
  fi
  echo "=== $(iso_now) $TASK_ID ===" >> "$logfile"
  if bash -c "$cmd" >> "$logfile" 2>&1; then
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
    echo "[dry-run] would run: claude -p (prompt: $preview...)"
    echo "[dry-run] log → $logfile"
    return 0
  fi
  if ! command -v claude >/dev/null 2>&1; then
    echo "[$TASK_ID] claude CLI not found in PATH" >&2
    return 1
  fi
  echo "=== $(iso_now) $TASK_ID ===" >> "$logfile"
  # `< /dev/null` skips claude -p's 3s "wait for stdin" warning when launchd
  # invokes us with no stdin attached.
  if claude -p "$prompt" < /dev/null >> "$logfile" 2>&1; then
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
      if run_deterministic "basic-memory reindex --project think-os"; then
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

    *)
      echo "Unknown task id: $TASK_ID" >&2
      echo "Known: daily-reindex weekly-review quarterly-archive morning-brief granola calendar clickup gmail slack" >&2
      exit 2
      ;;
  esac
}

run_task
