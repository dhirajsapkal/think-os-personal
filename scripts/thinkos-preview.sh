#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-preview.sh — Read-only "what would happen?" preview
# =============================================================================
# Tells the user (or an agent) exactly what end-to-end Think OS onboarding
# would do on this machine, without writing anything anywhere.
#
# Use this when you want to feel the UX of `Set up Think OS for me end to end`
# before committing to changes. Output is a clean numbered plan grouped by
# phase, followed by the exact apply commands.
#
# Usage:
#   scripts/thinkos-preview.sh \
#     [--os-home PATH] \
#     [--products LIST] \
#     [--bundle PRESET] \
#     [--bundle-items LIST]
#
# Examples:
#   scripts/thinkos-preview.sh
#   scripts/thinkos-preview.sh --products claude-code,claude-cowork --bundle pm
#   scripts/thinkos-preview.sh --os-home ~/Documents/MyVault --products all --bundle eng
#
# No flags? Sane defaults: ~/ThinkOS/vault, claude-code only, no bundle.
# =============================================================================
set -uo pipefail

PROJECT_NAME="think-os"
OS_HOME="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
PRODUCTS="claude-code"
BUNDLE=""
BUNDLE_ITEMS=""

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-preview.sh [options]

Read-only preview of Think OS onboarding. Tells you exactly what would happen
if you ran the real setup, without writing anything anywhere.

Options:
  --os-home PATH        Target vault path (default: ~/ThinkOS/vault)
  --products LIST       Products to wire up (default: claude-code)
                          Comma-separated. Valid: claude-cowork,claude-code,codex,all
  --bundle PRESET       Preview a bundle install (pm|eng|design|ops)
  --bundle-items LIST   Preview a custom item list (advanced)
  -h, --help            Show this help

Output is plain text and safe to read in any terminal.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --os-home)        OS_HOME="$2"; shift 2 ;;
    --products)       PRODUCTS="$2"; shift 2 ;;
    --bundle)         BUNDLE="$2"; shift 2 ;;
    --bundle-items)   BUNDLE_ITEMS="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *)                printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "$PRODUCTS" == "all" ]] && PRODUCTS="claude-cowork,claude-code,codex"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

has_product() {
  [[ ",$PRODUCTS," == *",$1,"* ]]
}

# State probes (read-only — never mutate)
exists_path() { [[ -e "$1" ]]; }
have_cmd()    { command -v "$1" >/dev/null 2>&1; }

is_protected_macos_path() {
  case "$OS_HOME" in
    "$HOME/Documents"|"$HOME/Documents"/*|"$HOME/Desktop"|"$HOME/Desktop"/*|"$HOME/Downloads"|"$HOME/Downloads"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Render the preview as a numbered plan.
step_n=0
next_step() {
  step_n=$((step_n + 1))
  printf '\n%d. %s\n' "$step_n" "$*"
}

bullet() {
  printf '   - %s\n' "$*"
}

note() {
  printf '   %s\n' "$*"
}

echo "============================================================"
echo "  Think OS — onboarding preview"
echo "============================================================"
echo "Nothing on this run will be written, modified, or registered."
echo "This is what would happen if you applied the real setup:"
echo
echo "  Vault path:    $OS_HOME"
echo "  Products:      $PRODUCTS"
[[ -n "$BUNDLE" ]] && echo "  Bundle preset: $BUNDLE"
[[ -n "$BUNDLE_ITEMS" ]] && echo "  Bundle items:  $BUNDLE_ITEMS"

# -----------------------------------------------------------------------------
# Phase 1: vault
# -----------------------------------------------------------------------------
next_step "Vault layout"
if exists_path "$OS_HOME"; then
  note "Folder exists. Setup would only copy missing template files (never overwrite)."
  # Count which template files are missing
  missing=0
  present=0
  while IFS= read -r -d '' file; do
    rel="${file#./}"
    if [[ -f "$OS_HOME/$rel" ]]; then
      present=$((present + 1))
    else
      missing=$((missing + 1))
    fi
  done < <(cd "$REPO_ROOT/templates" && find . -type f -print0 2>/dev/null)
  note "Templates already present: $present"
  note "Templates that would be created: $missing"
else
  total=$(cd "$REPO_ROOT/templates" && find . -type f 2>/dev/null | wc -l | tr -d ' ')
  bullet "Would create folder: $OS_HOME"
  bullet "Would copy $total template files (vault skeleton: 00 Home, 01 Now, 02 Projects, etc.)"
fi
if is_protected_macos_path; then
  note "WARNING: $OS_HOME is under Documents/Desktop/Downloads."
  note "         macOS may require granting Files/Folders or Full Disk Access to"
  note "         the apps that will read it (Claude Code, Cowork, Codex)."
fi

# -----------------------------------------------------------------------------
# Phase 2: Basic Memory
# -----------------------------------------------------------------------------
next_step "Basic Memory MCP server (the read/write bridge to your vault)"
if have_cmd basic-memory; then
  bm_version=$(basic-memory --version 2>/dev/null | head -1)
  bullet "Basic Memory already installed: ${bm_version:-yes}"
else
  bullet "Basic Memory not installed."
  if have_cmd uv; then
    bullet "uv is available; setup would run: uv tool install basic-memory"
  else
    bullet "uv is not installed either. You'd need: brew install uv  (then setup installs basic-memory)"
  fi
fi
if have_cmd basic-memory && basic-memory project ls --name "$PROJECT_NAME" >/dev/null 2>&1; then
  bullet "Basic Memory project '$PROJECT_NAME' already registered. Setup would reindex it."
else
  bullet "Would register Basic Memory project '$PROJECT_NAME' at: $OS_HOME"
  note   "Command: basic-memory project add $PROJECT_NAME \"$OS_HOME\" --local --default"
  bullet "Would reindex the project (30–60s on first run for a small vault)."
fi

# -----------------------------------------------------------------------------
# Phase 3: Claude Code
# -----------------------------------------------------------------------------
if has_product "claude-code"; then
  next_step "Claude Code adapter"
  if have_cmd claude; then
    bullet "Claude Code CLI found: $(command -v claude)"
  else
    bullet "Claude Code CLI not found. Adapter files would still be staged, but MCP registration would be skipped until you install it."
  fi
  if [[ -f "$HOME/.claude/CLAUDE.md" ]] && grep -q "BEGIN THINK OS" "$HOME/.claude/CLAUDE.md" 2>/dev/null; then
    bullet "Would update the Think OS block inside ~/.claude/CLAUDE.md (other content preserved)."
  else
    bullet "Would write the Think OS block into ~/.claude/CLAUDE.md (created if missing)."
  fi
  cc_cmd_count=$(find "$REPO_ROOT/adapters/claude-code/commands" -maxdepth 1 -name "*.md" ! -name "README.md" 2>/dev/null | wc -l | tr -d ' ')
  bullet "Would install $cc_cmd_count slash commands into ~/.claude/commands/"
  if have_cmd claude && claude mcp list 2>/dev/null | grep -q "basic-memory"; then
    bullet "basic-memory MCP already registered in Claude Code user scope."
  else
    bullet "Would register: claude mcp add basic-memory --scope user -- basic-memory mcp --project $PROJECT_NAME"
  fi
fi

# -----------------------------------------------------------------------------
# Phase 4: Codex
# -----------------------------------------------------------------------------
if has_product "codex"; then
  next_step "Codex adapter"
  if have_cmd codex; then
    bullet "Codex CLI found: $(command -v codex)"
  else
    bullet "Codex CLI not found. AGENTS.md block would still be written, MCP registration skipped."
  fi
  if [[ -f "$HOME/.codex/AGENTS.md" ]] && grep -q "BEGIN THINK OS" "$HOME/.codex/AGENTS.md" 2>/dev/null; then
    bullet "Would update the Think OS block inside ~/.codex/AGENTS.md."
  else
    bullet "Would write the Think OS block into ~/.codex/AGENTS.md (created if missing)."
  fi
  if have_cmd codex && codex mcp get basic-memory >/dev/null 2>&1; then
    bullet "basic-memory MCP already registered in Codex."
  else
    bullet "Would register: codex mcp add basic-memory -- basic-memory mcp --project $PROJECT_NAME"
  fi
fi

# -----------------------------------------------------------------------------
# Phase 5: Cowork
# -----------------------------------------------------------------------------
if has_product "claude-cowork"; then
  next_step "Claude Cowork adapter (MCP registration is UI-managed)"
  bullet "Would write ~/.thinkos/claude-cowork-instructions.md (personalization block)"
  bullet "Would write ~/.thinkos/claude-cowork-mcp.txt (MCP config to paste into Cowork settings)"
  if [[ -n "$BUNDLE" || -n "$BUNDLE_ITEMS" ]]; then
    bullet "Would write ~/.thinkos/claude-cowork-bundle.json (handoff for the Cowork bundle playbook)"
  fi
  note "After apply you'd: open Cowork → Settings → Connectors → add custom MCP → paste"
  note "the values, paste the personalization block, fully quit + reopen Cowork."
fi

# -----------------------------------------------------------------------------
# Phase 6: Bundle wizard
# -----------------------------------------------------------------------------
if [[ -n "$BUNDLE" || -n "$BUNDLE_ITEMS" ]]; then
  next_step "Plugin / connector bundle"

  # Source the catalog lib for resolution (read-only).
  if source "$REPO_ROOT/scripts/lib/catalog.sh" 2>/dev/null; then
    resolved=""
    if [[ -n "$BUNDLE" ]]; then
      resolved="$(catalog_resolve_preset "$BUNDLE" 2>/dev/null)" || resolved=""
    elif [[ -n "$BUNDLE_ITEMS" ]]; then
      resolved="$(printf '%s' "$BUNDLE_ITEMS" | tr ',' '\n')"
    fi

    if has_product "claude-code"; then
      cc_ids="$(printf '%s\n' "$resolved" | catalog_filter_by_target claude_code 2>/dev/null)"
      bullet "Claude Code target:"
      while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        name=$(catalog_get_field "$id" "name" 2>/dev/null)
        kind=$(catalog_kind "$id" "claude_code" 2>/dev/null)
        oauth=$(catalog_get_field "$id" "oauth" 2>/dev/null)
        oauth_tag=""
        [[ "$oauth" == "True" || "$oauth" == "true" ]] && oauth_tag="  [OAuth needed]"
        printf '       %-22s %s%s\n' "$id" "${name:-?} ($kind)" "$oauth_tag"
      done < <(printf '%s\n' "$cc_ids")
    fi

    if has_product "claude-cowork"; then
      cw_ids="$(printf '%s\n' "$resolved" | catalog_filter_by_target cowork 2>/dev/null)"
      bullet "Cowork target:"
      while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        name=$(catalog_get_field "$id" "name" 2>/dev/null)
        kind=$(catalog_kind "$id" "cowork" 2>/dev/null)
        oauth=$(catalog_get_field "$id" "oauth" 2>/dev/null)
        oauth_tag=""
        [[ "$oauth" == "True" || "$oauth" == "true" ]] && oauth_tag="  [OAuth needed]"
        printf '       %-22s %s%s\n' "$id" "${name:-?} ($kind)" "$oauth_tag"
      done < <(printf '%s\n' "$cw_ids")
      note "Cowork installs run inside Cowork via the /thinkos-bundle agent playbook."
      note "The preview above shows what the playbook would surface as install cards."
    fi
  else
    bullet "Could not load the catalog library to enumerate items. (This usually means PyYAML is missing — run scripts/lib/render-catalog.sh first.)"
  fi
fi

# -----------------------------------------------------------------------------
# Phase 7: After apply
# -----------------------------------------------------------------------------
next_step "After apply, you'd verify with"
printf '   scripts/thinkos-doctor.sh --deep --os-home %q --products %q\n' "$OS_HOME" "$PRODUCTS"
printf '\n   Then in a fresh session of your chosen tool:\n'
printf '     "Use Basic Memory to answer: who am I and what am I working on?"\n'

# -----------------------------------------------------------------------------
# Apply commands
# -----------------------------------------------------------------------------
echo
echo "============================================================"
echo "  To actually apply this plan, run:"
echo "============================================================"
apply_cmd="scripts/thinkos-setup.sh --os-home \"$OS_HOME\" --products \"$PRODUCTS\" --install-basic-memory --yes"
[[ -n "$BUNDLE" ]] && apply_cmd="$apply_cmd --bundle $BUNDLE"
[[ -n "$BUNDLE_ITEMS" ]] && apply_cmd="$apply_cmd --bundle-items $BUNDLE_ITEMS"
echo "  $apply_cmd"
echo
echo "Or, if you want one more confirmation pass, run with --dry-run first:"
echo "  $apply_cmd --dry-run"
echo
