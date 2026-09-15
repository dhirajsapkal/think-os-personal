#!/usr/bin/env bash
# =============================================================================
# scripts/lib/composio.sh — Composio bridge for Think OS
# =============================================================================
# Composio is reached as a LOCAL CLI, not as another MCP server. Three reasons:
#
#   1. Registering it as an MCP server pushes hundreds of tool schemas into
#      every session's context, whether or not a session touches Composio.
#      `composio search` discovers slugs on demand instead — the same
#      indexer-first pattern docs/automation-roadmap.md already uses.
#   2. The CLI works under launchd. `composio` installs to ~/.local/bin, which
#      thinkos-cron-run.sh already prepends to PATH, so scheduled jobs can use
#      it with no extra wiring.
#   3. It matches the repo rule of preferring a project's CLI over raw API
#      calls, and keeps auth in Composio's own store rather than in
#      ~/.thinkos/secrets.
#
# So: Composio covers what the first-party MCPs cannot (Figma comments being
# the motivating case — the Figma MCP is design read/write only and exposes no
# comments tool at all). It does not replace the connectors that already work.
#
# Usage from a script:
#   source "$(dirname "$0")/lib/composio.sh"
#   composio_require figma || exit 0
#   composio_exec FIGMA_GET_COMMENTS_IN_A_FILE '{"file_key":"..."}'
#
# Usage from a cron-prompt: call these through Bash, e.g.
#   bash <repo>/scripts/lib/composio.sh check figma
# =============================================================================
set -uo pipefail

composio_bin() {
  if command -v composio >/dev/null 2>&1; then
    command -v composio
    return 0
  fi
  # launchd's PATH may not have been extended yet when this is sourced early.
  for d in "$HOME/.local/bin" "$HOME/.npm-global/bin" "/opt/homebrew/bin" "/usr/local/bin"; do
    [[ -x "$d/composio" ]] && { echo "$d/composio"; return 0; }
  done
  return 1
}

# composio_available -> 0 if the CLI exists and a session is authenticated.
composio_available() {
  local bin
  bin="$(composio_bin)" || return 1
  "$bin" whoami >/dev/null 2>&1
}

# composio_linked <toolkit> -> 0 only if a connection is POSITIVELY confirmed.
#
# Fails closed. An earlier version matched on the "NoActiveConnection" string
# and returned success for anything else — so a typo'd probe slug came back
# "Tool ... not found" and was read as "connected". A connection check that
# reports ok when it cannot tell is worse than no check.
composio_linked() {
  local toolkit="$1" bin slug out
  bin="$(composio_bin)" || return 1
  slug="$(composio_probe_slug "$toolkit")"
  [[ -z "$slug" ]] && return 1          # no probe defined -> cannot confirm
  out="$("$bin" execute "$slug" -d '{}' 2>&1 || true)"
  case "$out" in
    *ToolNotFound*|*"not found"*)
      echo "[composio] probe slug '$slug' is invalid — fix composio_probe_slug()" >&2
      return 1 ;;
    *NoActiveConnection*|*"No active connection"*) return 1 ;;
  esac
  # Positive confirmation only: the router answered without a connection or
  # routing complaint, which means auth resolved. A provider-side 4xx about
  # arguments still counts as connected.
  case "$out" in
    *'"successful": true'*|*'"successful":true'*) return 0 ;;
    *ToolRouterV2_*) return 1 ;;
    *) return 0 ;;
  esac
}

# A real, read-only, argument-free slug per toolkit, used only to detect
# connection state. Verify any slug added here with `composio execute <SLUG>
# --get-schema` — an invalid one now fails closed and says so.
composio_probe_slug() {
  case "$1" in
    figma)  echo "FIGMA_DISCOVER_FIGMA_RESOURCES" ;;
    slack)  echo "SLACK_FETCH_CONVERSATION_LIST" ;;
    github) echo "GITHUB_GET_THE_AUTHENTICATED_USER" ;;
    *)      echo "" ;;
  esac
}

# composio_require <toolkit> — emit an actionable message and fail if unusable.
# Callers should treat failure as "skip this source", not "abort the run": a
# missing optional connector must never take a scheduled job down with it.
composio_require() {
  local toolkit="$1"
  if ! composio_bin >/dev/null; then
    echo "[composio] CLI not installed — skipping $toolkit." >&2
    echo "[composio] Install it, then run: composio link $toolkit" >&2
    return 1
  fi
  if ! composio_available; then
    echo "[composio] not authenticated — skipping $toolkit. Run: composio login" >&2
    return 1
  fi
  if ! composio_linked "$toolkit"; then
    echo "[composio] toolkit '$toolkit' has no active connection — skipping." >&2
    echo "[composio] Authorize it interactively: composio link $toolkit" >&2
    return 1
  fi
  return 0
}

# composio_exec <SLUG> <json> — run a tool, print raw JSON on stdout.
composio_exec() {
  local slug="$1" data="${2:-{\}}" bin
  bin="$(composio_bin)" || { echo "[composio] CLI not found" >&2; return 1; }
  "$bin" execute "$slug" -d "$data"
}

# Allow direct invocation so cron-prompts can shell out without sourcing:
#   bash lib/composio.sh check <toolkit>
#   bash lib/composio.sh exec <SLUG> '<json>'
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    check) composio_require "${2:?toolkit required}" && echo "ok" ;;
    exec)  composio_exec "${2:?slug required}" "${3:-{\}}" ;;
    bin)   composio_bin ;;
    *)     echo "Usage: composio.sh {check <toolkit>|exec <SLUG> <json>|bin}" >&2; exit 2 ;;
  esac
fi
