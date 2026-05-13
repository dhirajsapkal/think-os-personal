#!/usr/bin/env bash
set -u

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
  --products LIST         Comma-separated products: claude-cowork,claude-code,codex,all
  --json                  Print compact JSON instead of human-readable output
  --deep                  Run slower product CLI MCP checks
  --check-bundle           Compare installed plugins/connectors against the preset declared in the bundle state files
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
  PRODUCTS="claude-cowork,claude-code,codex"
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
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
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

if has_product "codex"; then
  check_command "codex"
  if command -v codex >/dev/null 2>&1; then
    if [[ "$DEEP" -eq 1 ]]; then
      TMP_OUT="$(mktemp)"
      if run_limited_to_file 12 "$TMP_OUT" codex mcp get basic-memory; then
        add_check "codex:mcp" ok "basic-memory MCP exists"
      else
        add_check "codex:mcp" warn "basic-memory MCP is not registered in Codex, or codex mcp get timed out"
      fi
      rm -f "$TMP_OUT"
    else
      add_check "codex:mcp" ok "fast mode skipped CLI MCP check; run --deep to verify"
    fi
  fi
fi

if has_product "claude-cowork"; then
  add_check "claude-cowork:mcp" warn "Cowork MCP registration is UI-managed; use adapters/claude-cowork/README.md"
fi

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
              if ! grep -q "$mcp_name" "$TMP_MCP"; then
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

  if has_product "claude-cowork"; then
    CW_BUNDLE_FILE="$HOME/.thinkos/claude-cowork-bundle.json"
    if [[ ! -f "$CW_BUNDLE_FILE" ]]; then
      add_check "claude-cowork:bundle" ok "no bundle declared (open Cowork and ask the agent to set up your Think OS bundle)"
    else
      # Validate it's parseable JSON
      if python3 -c "import sys,json; json.load(open(sys.argv[1]))" "$CW_BUNDLE_FILE" 2>/dev/null; then
        add_check "claude-cowork:bundle" ok "handoff file present ($CW_BUNDLE_FILE); verify install state in Cowork directly — Cowork plugin state is not observable from the CLI"
      else
        add_check "claude-cowork:bundle" warn "handoff file exists but is not valid JSON: $CW_BUNDLE_FILE; re-run the Cowork bundle playbook to regenerate it"
      fi
    fi
  fi

fi
# end --check-bundle

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
