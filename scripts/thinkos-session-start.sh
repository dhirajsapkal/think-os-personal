#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-session-start.sh — Claude Code SessionStart hook target
# =============================================================================
# Mechanical freshness check, injected as session context (v0.9.3).
#
# Emits AT MOST one line to stdout:
#   CURRENT FOCUS STALE: covers_week ended <date> — run /weekly-review
# No output when Current Focus is fresh. One line ≈ 15 tokens.
#
# Contract:
#   - Fast (<200ms): bash + awk/grep only on the hot path; python3 is used
#     only to parse ~/.thinkos/vaults.json when it exists.
#   - Fail-SILENT: any error -> exit 0 with no output. A broken hook must
#     never block or pollute session start.
#   - READ-ONLY against the vault. This script never writes anything.
#
# Vault resolution: default vault from ~/.thinkos/vaults.json, else
# $THINKOS_HOME, else ~/ThinkOS/vault.
#
# macOS bash 3.2 safe: no GNU-only flags, no date arithmetic (ISO dates
# compare lexicographically).
# =============================================================================

# Fail-silent: suppress all stderr for the rest of the script.
exec 2>/dev/null

main() {
  local vault="" focus="" end="" today=""

  # --- Resolve personal vault ------------------------------------------------
  local vaults_json="$HOME/.thinkos/vaults.json"
  if [[ -f "$vaults_json" ]] && command -v python3 >/dev/null 2>&1; then
    vault="$(python3 - "$vaults_json" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    vaults = data if isinstance(data, list) else data.get("vaults", [])
    for v in vaults:
        if v.get("default"):
            print(v.get("path", ""))
            break
except Exception:
    pass
PY
)"
  fi
  [[ -n "$vault" ]] || vault="${THINKOS_HOME:-$HOME/ThinkOS/vault}"

  focus="$vault/01 Now/Current Focus.md"
  [[ -f "$focus" ]] || return 0

  # --- covers_week end date from frontmatter only ----------------------------
  # awk: count "---" fences; only look at lines inside the first fence pair.
  # End date = last YYYY-MM-DD on the covers_week line. Template placeholders
  # ({{YYYY-MM-DD}}) contain no digits, so they parse to nothing -> silent.
  end="$(awk '/^---[[:space:]]*$/ { c++; next } c == 1 && /^covers_week:/ { print; exit } c >= 2 { exit }' "$focus" \
    | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | tail -n 1)"
  [[ -n "$end" ]] || return 0

  today="$(date +%Y-%m-%d)"
  [[ -n "$today" ]] || return 0

  # ISO dates compare lexicographically; no date arithmetic needed.
  if [[ "$end" < "$today" ]]; then
    printf 'CURRENT FOCUS STALE: covers_week ended %s — run /weekly-review\n' "$end"
  fi
  return 0
}

main "$@" || true
exit 0
