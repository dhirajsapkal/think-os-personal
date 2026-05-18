#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-install-bundle.sh — Think OS plugin/connector bundle installer
# =============================================================================
# Installs a bundle of catalog items for the Claude Code target.
#
# Usage:
#   scripts/thinkos-install-bundle.sh --target claude-code \
#     [--preset pm|eng|design|ops] \
#     [--items id1,id2,id3] \
#     [--all] \
#     [--dry-run] \
#     [--yes] \
#     [--skip-platform-check]
#
# Exactly one of --preset, --items, or --all is required.
# --target claude-code is also required.
# =============================================================================
set -uo pipefail

# ---------------------------------------------------------------------------
# Script globals
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET=""
PRESET=""
ITEMS_RAW=""
ALL=0
DRY_RUN=0
YES=0
SKIP_PLATFORM_CHECK=0

# ---------------------------------------------------------------------------
# Usage / help
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: scripts/thinkos-install-bundle.sh --target claude-code \
         [--preset pm|eng|design|ops] \
         [--items id1,id2,id3] \
         [--all] \
         [--dry-run] \
         [--yes] \
         [--skip-platform-check]

Installs a bundle of Think OS catalog items for the Claude Code CLI target.

Exactly one of --preset, --items, or --all is required.

Options:
  --target TARGET          Required. Only 'claude-code' is supported.
  --preset NAME            Install a named preset: pm | eng | design | ops
  --items LIST             Comma-separated catalog ids (advanced).
  --all                    Install every item available on the target.
  --dry-run                Print commands that would run; do not execute.
  --yes                    Non-interactive; skip install confirmation prompt.
  --skip-platform-check    Bypass the macOS-only guard (for testing only).
  -h, --help               Show this help and exit.

Examples:
  scripts/thinkos-install-bundle.sh --target claude-code --preset pm --yes
  scripts/thinkos-install-bundle.sh --target claude-code --items slack,notion --yes
  scripts/thinkos-install-bundle.sh --target claude-code --all --dry-run --skip-platform-check
  scripts/thinkos-install-bundle.sh --target claude-code --preset eng --dry-run --yes
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --preset)
      PRESET="$2"
      shift 2
      ;;
    --items)
      ITEMS_RAW="$2"
      shift 2
      ;;
    --all)
      ALL=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --yes)
      YES=1
      shift
      ;;
    --skip-platform-check)
      SKIP_PLATFORM_CHECK=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log() {
  printf '%s\n' "$*"
}

log_header() {
  log ""
  log "=== $* ==="
}

dry_run_cmd() {
  printf '[dry-run]'
  printf ' %q' "$@"
  printf '\n'
}

# ---------------------------------------------------------------------------
# Platform guard (macOS-only; bypass with --skip-platform-check for testing)
# ---------------------------------------------------------------------------
if [[ "$SKIP_PLATFORM_CHECK" -eq 0 ]] && [[ "$(uname -s)" != "Darwin" ]]; then
  log "Think OS bundle installer is macOS-only for the early alpha."
  log "Detected: $(uname -s). Linux/Windows support is not yet wired."
  log "If you need to test intent on a non-Darwin machine, use --skip-platform-check."
  exit 2
fi

# ---------------------------------------------------------------------------
# Validate --target
# ---------------------------------------------------------------------------
if [[ -z "$TARGET" ]]; then
  log "Error: --target is required." >&2
  usage >&2
  exit 2
fi

if [[ "$TARGET" != "claude-code" ]]; then
  log "Error: --target '$TARGET' is not supported by this script." >&2
  log "Valid value: claude-code" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Validate selection mode (exactly one of --preset, --items, --all)
# ---------------------------------------------------------------------------
mode_count=0
[[ -n "$PRESET" ]] && ((mode_count++)) || true
[[ -n "$ITEMS_RAW" ]] && ((mode_count++)) || true
[[ "$ALL" -eq 1 ]] && ((mode_count++)) || true

if [[ "$mode_count" -eq 0 ]]; then
  log "Error: one of --preset, --items, or --all is required." >&2
  usage >&2
  exit 2
fi

if [[ "$mode_count" -gt 1 ]]; then
  log "Error: only one of --preset, --items, or --all may be specified at a time." >&2
  usage >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# claude CLI check (skip in dry-run since user may be probing intent)
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" -eq 0 ]] && ! command -v claude >/dev/null 2>&1; then
  log "Claude Code CLI not found. Install Claude Code first, then re-run."
  exit 1
fi

# ---------------------------------------------------------------------------
# Source catalog library
# ---------------------------------------------------------------------------
# shellcheck source=scripts/lib/catalog.sh
source "$SCRIPT_DIR/lib/catalog.sh"

# ---------------------------------------------------------------------------
# Phase 1: Resolve requested ids
# ---------------------------------------------------------------------------
log_header "Resolving items"

RESOLVED_IDS=""

if [[ -n "$PRESET" ]]; then
  # Validate preset exists by attempting resolution; python will exit 1 on unknown preset
  valid_presets="pm eng design ops"
  found=0
  for p in $valid_presets; do
    [[ "$p" == "$PRESET" ]] && found=1 && break
  done
  if [[ "$found" -eq 0 ]]; then
    log "Error: unknown preset '$PRESET'. Valid presets: $valid_presets" >&2
    exit 2
  fi
  log "Resolving preset: $PRESET"
  RESOLVED_IDS="$(catalog_resolve_preset "$PRESET")" || {
    log "Error resolving preset '$PRESET'." >&2
    exit 2
  }
elif [[ -n "$ITEMS_RAW" ]]; then
  log "Resolving items: $ITEMS_RAW"
  # Convert comma-separated to newline-separated; validate each id exists
  all_ids="$(catalog_list_ids)"
  bad_ids=""
  while IFS= read -r id; do
    id="$(printf '%s' "$id" | tr -d '[:space:]')"
    [[ -z "$id" ]] && continue
    if printf '%s\n' "$all_ids" | grep -qx "$id"; then
      RESOLVED_IDS="${RESOLVED_IDS}${id}"$'\n'
    else
      bad_ids="${bad_ids} $id"
    fi
  done < <(printf '%s' "$ITEMS_RAW" | tr ',' '\n')

  if [[ -n "$bad_ids" ]]; then
    log "Error: unknown catalog id(s):$bad_ids" >&2
    log "Valid ids:" >&2
    printf '%s\n' "$all_ids" | sed 's/^/  /' >&2
    exit 2
  fi
else
  # --all
  log "Resolving all catalog ids"
  RESOLVED_IDS="$(catalog_list_ids)"
fi

if [[ -z "$(printf '%s' "$RESOLVED_IDS" | tr -d '[:space:]')" ]]; then
  log "No items resolved. Exiting."
  exit 0
fi

# ---------------------------------------------------------------------------
# Phase 2: Filter to those available on claude_code target
# ---------------------------------------------------------------------------
FILTERED_IDS="$(printf '%s\n' "$RESOLVED_IDS" | catalog_filter_by_target claude_code)"

# Determine skipped items
SKIPPED_IDS=""
while IFS= read -r id; do
  id="$(printf '%s' "$id" | tr -d '[:space:]')"
  [[ -z "$id" ]] && continue
  if ! printf '%s\n' "$FILTERED_IDS" | grep -qx "$id"; then
    SKIPPED_IDS="${SKIPPED_IDS}${id} "
  fi
done < <(printf '%s\n' "$RESOLVED_IDS")

if [[ -n "$(printf '%s' "$SKIPPED_IDS" | tr -d '[:space:]')" ]]; then
  log "Skipped (not available on Claude Code): ${SKIPPED_IDS% }"
fi

if [[ -z "$(printf '%s' "$FILTERED_IDS" | tr -d '[:space:]')" ]]; then
  log "No items available for Claude Code target after filtering. Exiting."
  exit 0
fi

# Build arrays for display
declare -a INSTALL_IDS=()
while IFS= read -r id; do
  id="$(printf '%s' "$id" | tr -d '[:space:]')"
  [[ -z "$id" ]] && continue
  INSTALL_IDS+=("$id")
done < <(printf '%s\n' "$FILTERED_IDS")

# ---------------------------------------------------------------------------
# Phase 3: Confirmation table
# ---------------------------------------------------------------------------
log_header "Confirmation"
log "Items to install on target: claude-code"
log ""
printf '%-30s %-40s %-16s %s\n' "ID" "NAME" "KIND" "NEEDS OAUTH?"
printf '%-30s %-40s %-16s %s\n' "------------------------------" "----------------------------------------" "----------------" "------------"

for id in "${INSTALL_IDS[@]}"; do
  item_name="$(catalog_get_field "$id" "name")"
  item_kind="$(catalog_kind "$id" "claude_code")"
  item_oauth="$(catalog_get_field "$id" "oauth")"
  oauth_label="no"
  [[ "$item_oauth" == "True" || "$item_oauth" == "true" ]] && oauth_label="YES - browser auth"
  printf '%-30s %-40s %-16s %s\n' "$id" "${item_name:-?}" "${item_kind:-?}" "$oauth_label"
done

log ""
log "Total: ${#INSTALL_IDS[@]} item(s)"

# ---------------------------------------------------------------------------
# Confirmation prompt
# ---------------------------------------------------------------------------
if [[ "$YES" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
  printf 'Install %d item(s)? [y/N] ' "${#INSTALL_IDS[@]}"
  read -r answer
  case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *)
      log "Aborted."
      exit 0
      ;;
  esac
fi

# ---------------------------------------------------------------------------
# Phase 4: Install loop
# ---------------------------------------------------------------------------
log_header "Installing"

# Status tracking uses parallel arrays (bash 3.2 compatible — macOS default
# bash has no associative arrays). The two arrays stay aligned by index.
STATUS_IDS=()
STATUS_VALUES=()

_status_set() {
  local id="$1"
  local value="$2"
  local i
  for i in "${!STATUS_IDS[@]}"; do
    if [[ "${STATUS_IDS[$i]}" == "$id" ]]; then
      STATUS_VALUES[$i]="$value"
      return
    fi
  done
  STATUS_IDS+=("$id")
  STATUS_VALUES+=("$value")
}

_status_get() {
  local id="$1"
  local i
  for i in "${!STATUS_IDS[@]}"; do
    if [[ "${STATUS_IDS[$i]}" == "$id" ]]; then
      printf '%s' "${STATUS_VALUES[$i]}"
      return
    fi
  done
  printf 'UNKNOWN'
}

# Cache `claude mcp list` once per invocation — the command can be slow because
# each line hits its server for a health probe. Repeated calls inside the
# install loop would add seconds per item and produce inconsistent reads if a
# health state flips mid-run.
_MCP_LIST_CACHE=""
_MCP_LIST_LOADED=0

_mcp_list_load() {
  if [[ "$_MCP_LIST_LOADED" -eq 0 ]]; then
    _MCP_LIST_CACHE="$(claude mcp list 2>/dev/null || true)"
    _MCP_LIST_LOADED=1
  fi
}

# Helper: check if an MCP name is registered locally (i.e. via `claude mcp add`,
# which writes into ~/.claude.json mcpServers and shows up at column 0 in
# `claude mcp list` as "<name>: <url-or-command>").
#
# Anchored match on `^<name>:` — the previous implementation fell through to a
# loose substring match that silently matched bridge entries (e.g. searching
# for "gmail" hit "claude.ai Gmail: https://gmailmcp.googleapis.com/..." via
# the URL substring) and made the installer report success while skipping the
# install. The fuzzy fallback is gone on purpose; if the strict name match
# fails we want to attempt the install.
_mcp_locally_registered() {
  local mcp_name="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 1  # In dry-run, treat as not registered so the command is printed.
  fi
  _mcp_list_load
  printf '%s\n' "$_MCP_LIST_CACHE" | grep -q "^${mcp_name}:"
}

# Helper: check if the service is being provided by the claude.ai marketplace
# bridge — `claude mcp list` shows these as
#   "claude.ai <Display Name>: <url> - <state>"
# When set, we want to skip the local install entirely: a local `claude mcp
# add` would create a duplicate that requires its own OAuth, never replace the
# bridge entry, and just confuse the user.
#
# bridge_match must be the exact display name as it appears in
# `claude mcp list` after the literal "claude.ai " prefix.
#
# Note: unlike _mcp_locally_registered, this runs in dry-run too — it is a
# read-only probe, and the whole point of dry-run is to surface what the
# installer would actually do. A bridge-intercepted item showing "OK
# (dry-run)" would be a lie.
_mcp_provided_by_bridge() {
  local bridge_match="$1"
  [[ -z "$bridge_match" ]] && return 1
  _mcp_list_load
  # Escape any regex specials in bridge_match (display names have spaces and
  # may include parens or dots, e.g. "Atlassian", "Zoom for Claude").
  local escaped
  escaped="$(printf '%s' "$bridge_match" | sed 's/[][\\.*^$(){}?+|/]/\\&/g')"
  printf '%s\n' "$_MCP_LIST_CACHE" | grep -q "^claude\.ai ${escaped}:"
}

# Collect unique marketplaces for plugin/skill_bundle items.
# Use a newline-delimited string + grep because bash 3.2 lacks associative arrays.
MARKETPLACE_SEEN=""

for id in "${INSTALL_IDS[@]}"; do
  item_kind="$(catalog_kind "$id" "claude_code")"
  if [[ "$item_kind" == "plugin" || "$item_kind" == "skill_bundle" ]]; then
    mp="$(catalog_get_field "$id" "claude_code.marketplace")"
    if [[ -n "$mp" ]] && ! printf '%s\n' "$MARKETPLACE_SEEN" | grep -qx "$mp"; then
      MARKETPLACE_SEEN="${MARKETPLACE_SEEN}${mp}"$'\n'
    fi
  fi
done

# Register marketplaces first (deduplicated)
if [[ -n "$(printf '%s' "$MARKETPLACE_SEEN" | tr -d '[:space:]')" ]]; then
  log "Registering marketplaces..."
  while IFS= read -r mp; do
    [[ -z "$mp" ]] && continue
    if [[ "$DRY_RUN" -eq 1 ]]; then
      dry_run_cmd env CLAUDE_CODE_SYNC_PLUGIN_INSTALL=1 claude -p --bare "/plugin marketplace add $mp"
    else
      log "  Adding marketplace: $mp"
      mp_stderr="$(CLAUDE_CODE_SYNC_PLUGIN_INSTALL=1 claude -p --bare "/plugin marketplace add $mp" 2>&1 >/dev/null)" || {
        # Marketplace may already be registered; treat as non-fatal
        log "  Note: marketplace add returned non-zero (may already be registered): $mp_stderr"
      }
    fi
  done < <(printf '%s\n' "$MARKETPLACE_SEEN")
fi

# Now install each item
for id in "${INSTALL_IDS[@]}"; do
  item_kind="$(catalog_kind "$id" "claude_code")"
  item_name="$(catalog_get_field "$id" "name")"

  log ""
  log "Installing: $id ($item_name) [kind: $item_kind]"

  case "$item_kind" in
    mcp_remote)
      mcp_name="$(catalog_get_field "$id" "claude_code.mcp_name")"
      transport="$(catalog_get_field "$id" "claude_code.transport")"
      url="$(catalog_get_field "$id" "claude_code.url")"
      bridge_match="$(catalog_get_field "$id" "claude_code.bridge_match")"

      if [[ -z "$mcp_name" || -z "$transport" || -z "$url" ]]; then
        _status_set "$id" "FAILED: missing mcp_name/transport/url in catalog"
        log "  FAILED: incomplete mcp_remote config for $id"
        continue
      fi

      if _mcp_provided_by_bridge "$bridge_match"; then
        _status_set "$id" "BRIDGE: provided by claude.ai (${bridge_match})"
        log "  BRIDGE: '$mcp_name' is already provided by the claude.ai marketplace as '${bridge_match}' — skipping local install"
        continue
      fi

      if _mcp_locally_registered "$mcp_name"; then
        _status_set "$id" "SKIPPED: '$mcp_name' already in mcp list"
        log "  SKIPPED: '$mcp_name' already registered locally in claude mcp list"
        continue
      fi

      if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_cmd claude mcp add --transport "$transport" "$mcp_name" "$url" --scope user
        _status_set "$id" "OK (dry-run)"
      else
        if claude mcp add --transport "$transport" "$mcp_name" "$url" --scope user 2>&1; then
          _status_set "$id" "OK"
          log "  OK: registered MCP '$mcp_name'"
        else
          _status_set "$id" "FAILED: claude mcp add exited non-zero"
          log "  FAILED: could not register MCP '$mcp_name'"
        fi
      fi
      ;;

    mcp_stdio)
      mcp_name="$(catalog_get_field "$id" "claude_code.mcp_name")"
      command_bin="$(catalog_get_field "$id" "claude_code.command")"
      bridge_match="$(catalog_get_field "$id" "claude_code.bridge_match")"

      if [[ -z "$mcp_name" || -z "$command_bin" ]]; then
        _status_set "$id" "FAILED: missing mcp_name/command in catalog"
        log "  FAILED: incomplete mcp_stdio config for $id"
        continue
      fi

      # Build args array from catalog
      args_str=""
      # Retrieve args as newline-separated list via catalog helper
      args_raw="$(catalog_get_field "$id" "claude_code.args")" || true

      if _mcp_provided_by_bridge "$bridge_match"; then
        _status_set "$id" "BRIDGE: provided by claude.ai (${bridge_match})"
        log "  BRIDGE: '$mcp_name' is already provided by the claude.ai marketplace as '${bridge_match}' — skipping local install"
        continue
      fi

      if _mcp_locally_registered "$mcp_name"; then
        _status_set "$id" "SKIPPED: '$mcp_name' already in mcp list"
        log "  SKIPPED: '$mcp_name' already registered locally in claude mcp list"
        continue
      fi

      # Build the command line; args_raw may be a Python list repr or newline-separated
      # catalog_get_field for a list returns e.g. "['granola-mcp']" from Python repr
      # We parse the simple single-item case and multi-item case
      declare -a stdio_args=()
      if [[ -n "$args_raw" ]]; then
        # Strip Python list brackets and quotes, split on commas
        cleaned="$(printf '%s' "$args_raw" | tr -d "[]'" | tr ',' '\n')"
        while IFS= read -r arg; do
          arg="$(printf '%s' "$arg" | tr -d '[:space:]')"
          [[ -n "$arg" ]] && stdio_args+=("$arg")
        done < <(printf '%s\n' "$cleaned")
      fi

      if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_cmd claude mcp add "$mcp_name" --scope user -- "$command_bin" "${stdio_args[@]+"${stdio_args[@]}"}"
        _status_set "$id" "OK (dry-run)"
      else
        if claude mcp add "$mcp_name" --scope user -- "$command_bin" "${stdio_args[@]+"${stdio_args[@]}"}" 2>&1; then
          _status_set "$id" "OK"
          log "  OK: registered stdio MCP '$mcp_name'"
        else
          _status_set "$id" "FAILED: claude mcp add (stdio) exited non-zero"
          log "  FAILED: could not register stdio MCP '$mcp_name'"
        fi
      fi
      ;;

    plugin|skill_bundle)
      mp="$(catalog_get_field "$id" "claude_code.marketplace")"
      plugin_slug="$(catalog_get_field "$id" "claude_code.plugin")"

      if [[ -z "$mp" || -z "$plugin_slug" ]]; then
        _status_set "$id" "FAILED: missing marketplace/plugin in catalog"
        log "  FAILED: incomplete plugin config for $id"
        continue
      fi

      if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_cmd env CLAUDE_CODE_SYNC_PLUGIN_INSTALL=1 claude -p --bare "/plugin install ${plugin_slug}@${mp}"
        _status_set "$id" "OK (dry-run)"
      else
        plugin_exit=0
        plugin_out="$(CLAUDE_CODE_SYNC_PLUGIN_INSTALL=1 claude -p --bare "/plugin install ${plugin_slug}@${mp}" 2>&1)" || plugin_exit=$?
        if [[ "$plugin_exit" -eq 0 ]]; then
          _status_set "$id" "OK"
          log "  OK: installed plugin '${plugin_slug}@${mp}'"
        else
          _status_set "$id" "FAILED: plugin install exited $plugin_exit"
          log "  FAILED: could not install plugin '${plugin_slug}@${mp}'"
          log "  Output: $plugin_out"
        fi
      fi
      ;;

    "")
      _status_set "$id" "FAILED: kind is empty (item may lack claude_code block)"
      log "  FAILED: no claude_code.kind found for $id"
      ;;

    *)
      _status_set "$id" "FAILED: unknown kind '$item_kind'"
      log "  FAILED: unknown kind '$item_kind' for $id"
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Phase 5: Summary table
# ---------------------------------------------------------------------------
log_header "Summary"
printf '%-30s %s\n' "ID" "STATUS"
printf '%-30s %s\n' "------------------------------" "-------------------------------"

overall_exit=0
for id in "${INSTALL_IDS[@]}"; do
  status="$(_status_get "$id")"
  printf '%-30s %s\n' "$id" "$status"
  if [[ "$status" == FAILED* ]]; then
    overall_exit=1
  fi
done

# ---------------------------------------------------------------------------
# Phase 6: OAuth checklist
# ---------------------------------------------------------------------------
log_header "Next steps (OAuth)"

oauth_list=""
for id in "${INSTALL_IDS[@]}"; do
  status="$(_status_get "$id")"
  # Show OAuth steps for items that were installed or would be installed
  if [[ "$status" == "OK" || "$status" == "OK (dry-run)" ]]; then
    oauth_val="$(catalog_get_field "$id" "oauth")"
    if [[ "$oauth_val" == "True" || "$oauth_val" == "true" ]]; then
      item_name="$(catalog_get_field "$id" "name")"
      mcp_name="$(catalog_get_field "$id" "claude_code.mcp_name")" 2>/dev/null || mcp_name="$id"
      [[ -z "$mcp_name" ]] && mcp_name="$id"
      oauth_list="${oauth_list}  - ${item_name} (${id}): Run \`claude\`, type \`/mcp\`, select '${mcp_name}', complete browser flow.\n"
    fi
  fi
done

if [[ -n "$oauth_list" ]]; then
  log "The following items require OAuth authentication after install:"
  log ""
  printf '%b' "$oauth_list"
  log ""
  log "You can trigger auth at any time by opening Claude Code and calling a tool"
  log "from that MCP — it will automatically prompt for browser authentication."
else
  log "No OAuth steps required for the installed items."
fi

# ---------------------------------------------------------------------------
# Phase 6.5: Claude.ai bridge note
# ---------------------------------------------------------------------------
# Items detected as already provided by the claude.ai marketplace bridge are
# usable immediately — no local install, no separate OAuth — as long as the
# user stays signed into claude.ai with that connector enabled. Surface this
# explicitly so the user understands why some items were "skipped" even
# though they will work fine when they call tools from those services.
bridge_list=""
for id in "${INSTALL_IDS[@]}"; do
  status="$(_status_get "$id")"
  if [[ "$status" == BRIDGE:* ]]; then
    item_name="$(catalog_get_field "$id" "name")"
    bridge_match="$(catalog_get_field "$id" "claude_code.bridge_match")"
    bridge_list="${bridge_list}  - ${item_name} (${id}) → claude.ai \"${bridge_match}\"\n"
  fi
done

if [[ -n "$bridge_list" ]]; then
  log ""
  log "Already provided by the claude.ai marketplace bridge (no local install needed):"
  log ""
  printf '%b' "$bridge_list"
  log ""
  log "These work as long as you stay signed into claude.ai with the connector enabled."
  log "Tools appear under the mcp__claude_ai_<Service>__* namespace."
  log "If you ever lose access to claude.ai or want a CLI-only install, re-run this"
  log "installer with --items <id> after disconnecting the bridge entry."
fi

# ---------------------------------------------------------------------------
# Phase 7: Write preset marker file (only on full success, only for --preset)
# ---------------------------------------------------------------------------
if [[ "$overall_exit" -eq 0 && -n "$PRESET" && "$DRY_RUN" -eq 0 ]]; then
  mkdir -p "$HOME/.thinkos"
  printf '%s\n' "$PRESET" > "$HOME/.thinkos/claude-code-bundle.txt"
  log ""
  log "Preset marker written to $HOME/.thinkos/claude-code-bundle.txt"
fi

exit "$overall_exit"
