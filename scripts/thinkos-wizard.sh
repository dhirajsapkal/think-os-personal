#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-wizard.sh — Interactive Think OS setup wizard
# =============================================================================
# DOS-style guided installer. Walks the user through every setup choice
# one question at a time, with clear screen transitions. No pre-selections;
# only suggestions with sensible defaults the user can override.
#
# Usage:
#   scripts/thinkos-wizard.sh             # interactive, real apply at the end
#   scripts/thinkos-wizard.sh --preview   # interactive, but never applies;
#                                         # shows the apply command instead
#
# Non-interactive demo (e.g. piped stdin or CI), the wizard prints rules
# between steps instead of clearing the screen.
# =============================================================================
set -uo pipefail

PROJECT_NAME="think-os"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE_PREVIEW=0

VAULT_PATH=""
PRODUCTS_LIST=""
INSTALL_BM=1
BUNDLE=""

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-wizard.sh [--preview]

Interactive setup wizard for Think OS. Walks you through every choice
(vault location, products, Basic Memory, plugin bundle), shows the plan
for review, then applies.

Options:
  --preview    Walk through the wizard but never apply. At the end you
               see the exact apply command instead of running it.
  -h, --help   Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preview)  MODE_PREVIEW=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    *)          echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# -----------------------------------------------------------------------------
# Screen plumbing
# -----------------------------------------------------------------------------
# When stdout is a TTY we clear between steps for a proper installer feel.
# When it's a pipe (demos, CI) we print a horizontal rule instead so the
# transitions are visible in captured output.
new_screen() {
  if [[ -t 1 ]]; then
    clear
  else
    printf '\n══════════════════════════════════════════════════════════════════════\n\n'
  fi
}

pause() {
  local _unused
  printf '\n'
  read -r -p "  Press ENTER to continue... " _unused || true
}

step_header() {
  local n="$1" total="$2" title="$3"
  printf '\n'
  printf '══════════════════════════════════════════════════════════════════════\n'
  printf '  STEP %s of %s  ·  %s\n' "$n" "$total" "$title"
  printf '══════════════════════════════════════════════════════════════════════\n\n'
}

# -----------------------------------------------------------------------------
# Step 0 — welcome
# -----------------------------------------------------------------------------
welcome() {
  new_screen
  cat <<'EOF'

╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║                  T H I N K   O S   S E T U P                       ║
║                      Early Alpha · v0.2.0                          ║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝

  Welcome.

  This wizard walks you through setting up Think OS — a markdown-first
  personal context OS — on your Mac. You'll be asked five short questions
  in sequence. After the last one, you'll see the full plan and can
  approve, redo the wizard, or quit.

  Nothing is written to disk until you reach the review screen and
  explicitly choose to apply.

  Press Ctrl+C at any prompt to abort.

EOF
  if [[ "$MODE_PREVIEW" -eq 1 ]]; then
    cat <<'EOF'
  ┌──────────────────────────────────────────────────────────────────┐
  │  PREVIEW MODE — no changes will be applied at the end.           │
  │  You will see the exact apply command instead.                   │
  └──────────────────────────────────────────────────────────────────┘

EOF
  fi
  local _unused
  read -r -p "  Press ENTER to begin... " _unused || true
}

# -----------------------------------------------------------------------------
# Step 1 — vault location
# -----------------------------------------------------------------------------
step_vault() {
  new_screen
  step_header 1 5 "VAULT LOCATION"
  cat <<'EOF'
  Where should your Think OS vault live?

  Your vault is a folder of markdown files: identity, projects,
  decisions, work log, people. Think OS reads and writes them through
  Basic Memory MCP — on disk they're just plain markdown you can also
  open in Obsidian or any text editor.

  Choose a location:

    [1] ~/ThinkOS/vault         Recommended. Avoids macOS permission
                                friction with Documents/Desktop.

    [2] ~/Documents/ThinkOS     Under Documents. Convenient if you
                                already keep notes there, but Claude
                                Code / Cowork / Codex may need
                                Files & Folders access granted.

    [3] Custom path             Type your own.

EOF
  local choice
  read -r -p "  Enter your choice [1]: " choice || choice=""
  choice="${choice:-1}"

  case "$choice" in
    1) VAULT_PATH="$HOME/ThinkOS/vault" ;;
    2) VAULT_PATH="$HOME/Documents/ThinkOS" ;;
    3)
       local custom
       read -r -p "  Enter the full vault path: " custom || custom=""
       VAULT_PATH="${custom:-$HOME/ThinkOS/vault}"
       ;;
    *)
       printf '\n  Invalid choice, using the recommended default.\n'
       VAULT_PATH="$HOME/ThinkOS/vault"
       ;;
  esac

  # Expand leading ~ if user typed it
  VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

  printf '\n  → Vault path: %s\n' "$VAULT_PATH"
  pause
}

# -----------------------------------------------------------------------------
# Step 2 — products
# -----------------------------------------------------------------------------
step_products() {
  new_screen
  step_header 2 5 "AGENT PRODUCTS"
  cat <<'EOF'
  Which agentic tools should Think OS be wired into?

  For each one you say yes to, the wizard will:
    · install global instructions so the agent reads your vault
    · register the Basic Memory MCP server (where automatable)
    · install adapter-specific slash commands or playbooks

  Answer Y or N for each. Press ENTER to accept the default in brackets.

EOF
  local cc cw cx
  read -r -p "  Wire up Claude Code CLI?         [Y/n]: " cc || cc=""
  read -r -p "  Wire up Claude Cowork desktop?   [Y/n]: " cw || cw=""
  read -r -p "  Wire up OpenAI Codex?            [Y/n]: " cx || cx=""

  local selected=""
  [[ -z "$cc" || "$cc" =~ ^[Yy] ]] && selected="${selected}claude-code,"
  [[ -z "$cw" || "$cw" =~ ^[Yy] ]] && selected="${selected}claude-cowork,"
  [[ -z "$cx" || "$cx" =~ ^[Yy] ]] && selected="${selected}codex,"
  selected="${selected%,}"

  if [[ -z "$selected" ]]; then
    printf '\n  You did not select any products. At least one is required.\n'
    printf '  Restarting this step in 2 seconds...\n'
    sleep 2
    step_products
    return
  fi

  PRODUCTS_LIST="$selected"
  printf '\n  → Products: %s\n' "$PRODUCTS_LIST"
  pause
}

# -----------------------------------------------------------------------------
# Step 3 — Basic Memory
# -----------------------------------------------------------------------------
step_basic_memory() {
  new_screen
  step_header 3 5 "BASIC MEMORY MCP"
  cat <<'EOF'
  Basic Memory is the MCP server that exposes your vault to every
  agentic tool. It's required.

EOF
  if command -v basic-memory >/dev/null 2>&1; then
    local bmver
    bmver="$(basic-memory --version 2>/dev/null | head -1)"
    printf '  Status: ✓ already installed (%s)\n' "${bmver:-yes}"
    printf '\n'
    printf '  Nothing to install. Setup will register the "think-os"\n'
    printf '  project against your vault path and reindex it.\n'
    INSTALL_BM=0
  elif command -v uv >/dev/null 2>&1; then
    printf '  Status: ✗ not installed (but uv is available)\n\n'
    printf '  Setup can install it for you with:\n'
    printf '      uv tool install basic-memory\n\n'
    local ans
    read -r -p "  Install Basic Memory automatically? [Y/n]: " ans || ans=""
    if [[ -z "$ans" || "$ans" =~ ^[Yy] ]]; then
      INSTALL_BM=1
    else
      INSTALL_BM=0
      printf '\n  ⚠ Setup will still write files, but Basic Memory itself\n'
      printf '    will NOT be installed. You will need to install it later\n'
      printf '    before any agentic tool can read your vault.\n'
    fi
  else
    printf '  Status: ✗ not installed (and uv is not installed either)\n\n'
    printf '  Both `uv` (a Python package manager) and `basic-memory`\n'
    printf '  are required. Install uv first, then re-run this wizard:\n\n'
    printf '      brew install uv\n\n'
    printf '  Aborting.\n\n'
    exit 1
  fi

  pause
}

# -----------------------------------------------------------------------------
# Step 4 — plugin bundle
# -----------------------------------------------------------------------------
step_bundle() {
  new_screen
  step_header 4 5 "PLUGIN / CONNECTOR BUNDLE"
  cat <<'EOF'
  Think OS ships role-based bundles that install a curated set of
  plugins and connectors. You can pick one, or skip and install
  items individually later.

    [1] pm       Product management
                 Slack · Gmail · Notion · Linear · Granola · Figma
                 + PM and Productivity skills

    [2] eng      Engineering
                 Slack · Gmail · Atlassian Rovo · Linear
                 + Engineering and Productivity skills

    [3] design   Design
                 Slack · Gmail · Notion · Figma · Granola
                 + Design and Productivity skills

    [4] ops      Operations
                 Slack · Gmail · MS 365 · Notion · QuickBooks
                 + Productivity skills

    [5] skip     No bundle. Install items individually later.

EOF
  local choice
  read -r -p "  Enter your choice [5]: " choice || choice=""
  case "${choice:-5}" in
    1)         BUNDLE="pm" ;;
    2)         BUNDLE="eng" ;;
    3)         BUNDLE="design" ;;
    4)         BUNDLE="ops" ;;
    5|skip|"") BUNDLE="" ;;
    *)
      printf '\n  Invalid choice, defaulting to skip.\n'
      BUNDLE=""
      ;;
  esac

  printf '\n'
  if [[ -z "$BUNDLE" ]]; then
    printf '  → No bundle selected. You can run the bundle wizard later:\n'
    printf '       scripts/thinkos-install-bundle.sh --target claude-code --preset <name>\n'
  else
    printf '  → Bundle: %s\n' "$BUNDLE"
  fi
  pause
}

# -----------------------------------------------------------------------------
# Step 5 — review
# Returns 0 = apply, 1 = back-to-start, 2 = quit
# -----------------------------------------------------------------------------
step_review() {
  new_screen
  step_header 5 5 "REVIEW"
  cat <<EOF
  Here are the choices you made:

    Vault path:        $VAULT_PATH
    Products:          $PRODUCTS_LIST
    Install BM:        $([[ "$INSTALL_BM" -eq 1 ]] && echo "yes (via uv)" || echo "no — already installed or manual")
    Bundle:            ${BUNDLE:-skip}

──────────────────────────────────────────────────────────────────────
  What will happen on apply:
──────────────────────────────────────────────────────────────────────
EOF
  printf '  1. Vault — create %s if it does not exist;\n' "$VAULT_PATH"
  printf '             copy missing template files (identity, current-focus,\n'
  printf '             active-projects, decisions, people, work-log).\n\n'
  if [[ "$INSTALL_BM" -eq 1 ]]; then
    printf '  2. Basic Memory — install via uv tool install basic-memory;\n'
  else
    printf '  2. Basic Memory — already installed;\n'
  fi
  printf '             register a "think-os" project pointing at the vault;\n'
  printf '             run basic-memory sync to build the initial index.\n\n'
  printf '  3. Adapters — for each selected product (%s):\n' "$PRODUCTS_LIST"
  printf '             write global instructions so the agent reads the vault;\n'
  printf '             register the Basic Memory MCP server where automatable;\n'
  printf '             install adapter-specific slash commands / playbooks.\n\n'
  if [[ -n "$BUNDLE" ]]; then
    printf '  4. Bundle  — install the "%s" preset via thinkos-install-bundle.sh;\n' "$BUNDLE"
    printf '             writes connector configs and skill files for the selected\n'
    printf '             products; OAuth steps are listed post-apply.\n\n'
  else
    printf '  4. Bundle  — skipped (no preset selected).\n\n'
  fi
  printf '  5. Verify  — run thinkos-doctor.sh --deep to report any remaining\n'
  printf '             gaps (MCP registration, OAuth pending, etc.).\n'
  printf '\n══════════════════════════════════════════════════════════════════════\n'

  if [[ "$MODE_PREVIEW" -eq 1 ]]; then
    cat <<'EOF'
  PREVIEW MODE — no changes will be applied.

    [A] Show me the exact apply command
    [B] Back to start (redo the wizard)
    [Q] Quit
EOF
  else
    cat <<'EOF'
    [A] Apply this plan now
    [B] Back to start (redo the wizard)
    [Q] Quit without changes
EOF
  fi
  printf '\n'

  local final
  read -r -p "  Enter your choice [A]: " final || final=""
  case "${final:-A}" in
    [Aa]) return 0 ;;
    [Bb]) return 1 ;;
    [Qq]) return 2 ;;
    *)    return 0 ;;
  esac
}

# -----------------------------------------------------------------------------
# Compute the OAuth-pending list from the chosen bundle + products. Read-only
# query against the catalog. Returns a comma-separated string of catalog ids
# that need OAuth on any selected target.
# -----------------------------------------------------------------------------
_compute_oauth_pending() {
  [[ -z "$BUNDLE" ]] && { printf ''; return; }
  # shellcheck source=lib/catalog.sh
  source "$SCRIPT_DIR/lib/catalog.sh" 2>/dev/null || { printf ''; return; }

  local resolved
  resolved="$(catalog_resolve_preset "$BUNDLE" 2>/dev/null)" || { printf ''; return; }

  local pending=""
  local id oauth
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    oauth="$(catalog_get_field "$id" "oauth" 2>/dev/null)"
    if [[ "$oauth" == "True" || "$oauth" == "true" ]]; then
      pending="${pending}${id},"
    fi
  done < <(printf '%s\n' "$resolved")

  printf '%s' "${pending%,}"
}

# -----------------------------------------------------------------------------
# Apply (or preview-end)
# -----------------------------------------------------------------------------
apply() {
  new_screen
  printf '\n══════════════════════════════════════════════════════════════════════\n'
  if [[ "$MODE_PREVIEW" -eq 1 ]]; then
    printf '  PREVIEW MODE — apply command\n'
  else
    printf '  APPLYING\n'
  fi
  printf '══════════════════════════════════════════════════════════════════════\n\n'

  local args=(--os-home "$VAULT_PATH" --products "$PRODUCTS_LIST" --yes)
  [[ "$INSTALL_BM" -eq 1 ]] && args+=(--install-basic-memory)
  [[ -n "$BUNDLE" ]] && args+=(--bundle "$BUNDLE")

  if [[ "$MODE_PREVIEW" -eq 1 ]]; then
    printf '  The command that would have been run:\n\n'
    printf '    scripts/thinkos-setup.sh'
    local a
    for a in "${args[@]}"; do printf ' %q' "$a"; done
    printf '\n\n'
    printf '  No changes were made. Re-run this wizard without --preview\n'
    printf '  to apply, or copy-paste the command above.\n\n'
    return
  fi

  bash "$SCRIPT_DIR/thinkos-setup.sh" "${args[@]}"
  local setup_exit=$?

  # Write the Phase-1-complete state file so /thinkos-continue can resume.
  if [[ "$setup_exit" -eq 0 ]]; then
    local oauth_pending
    oauth_pending="$(_compute_oauth_pending)"
    local state_args=(init --vault "$VAULT_PATH" --products "$PRODUCTS_LIST")
    [[ -n "$BUNDLE" ]] && state_args+=(--bundle "$BUNDLE")
    [[ -n "$oauth_pending" ]] && state_args+=(--oauth-pending "$oauth_pending")
    bash "$SCRIPT_DIR/thinkos-state.sh" "${state_args[@]}" >/dev/null 2>&1 || true
    bash "$SCRIPT_DIR/thinkos-vault.sh" migrate >/dev/null 2>&1 || true
  fi

  # ---------------------------------------------------------------------------
  # SETUP COMPLETE — explicit numbered checklist of what's left for the human.
  # ---------------------------------------------------------------------------
  printf '\n══════════════════════════════════════════════════════════════════════\n'
  printf '  PHASE 1 COMPLETE — %d STEPS LEFT (manual)\n' "$(_count_manual_steps)"
  printf '══════════════════════════════════════════════════════════════════════\n\n'
  printf '  Everything the installer can automate is done. A few things still\n'
  printf '  require you. Walk through these in order:\n\n'

  local n=0

  # Cowork-specific manual steps
  if [[ ",$PRODUCTS_LIST," == *",claude-cowork,"* ]]; then
    n=$((n + 1))
    printf '  [%d] Wire up Cowork (the script cannot touch its settings):\n' "$n"
    printf '      a. Open Cowork → Settings → Connectors / MCP Servers\n'
    printf '      b. Add a custom MCP using values from:\n'
    printf '           ~/.thinkos/claude-cowork-mcp.txt\n'
    printf '      c. Paste the personalization block from:\n'
    printf '           ~/.thinkos/claude-cowork-instructions.md\n'
    printf '         (already on your clipboard if pbcopy worked)\n'
    printf '      d. Fully quit + reopen Cowork (not just close window)\n\n'
  fi

  # OAuth for connectors that need it
  if [[ -n "$BUNDLE" ]]; then
    local oauth_list
    oauth_list="$(_compute_oauth_pending)"
    if [[ -n "$oauth_list" ]]; then
      n=$((n + 1))
      printf '  [%d] Complete OAuth for each connector that needs it:\n' "$n"
      if [[ ",$PRODUCTS_LIST," == *",claude-code,"* ]]; then
        printf '      Claude Code: open `claude`, type `/mcp`, authorize:\n'
        printf '        %s\n' "${oauth_list//,/, }"
      fi
      if [[ ",$PRODUCTS_LIST," == *",claude-cowork,"* ]]; then
        printf '      Cowork: Settings → Connectors → Authorize each item.\n'
      fi
      printf '\n'
    fi
  fi

  # Restart the agent apps
  n=$((n + 1))
  printf '  [%d] Restart your agent app(s) so MCPs and plugins load:\n' "$n"
  [[ ",$PRODUCTS_LIST," == *",claude-code,"* ]]   && printf '      · Claude Code: quit and reopen\n'
  [[ ",$PRODUCTS_LIST," == *",claude-cowork,"* ]] && printf '      · Cowork: fully quit (Cmd+Q) and reopen\n'
  [[ ",$PRODUCTS_LIST," == *",codex,"* ]]         && printf '      · Codex: start a fresh session\n'
  printf '\n'

  # Phase 2 — continue to context seeding
  n=$((n + 1))
  printf '  [%d] After the steps above, continue to Phase 2 (context seeding):\n' "$n"
  printf '      The agent will read your connected tools (Slack, Gmail, Granola,\n'
  printf '      Calendar, etc.) and draft your Identity, Current Focus, Project\n'
  printf '      Index, and People files. You review and approve every draft.\n\n'
  printf '      Two ways to start Phase 2:\n'
  printf '      · In Claude Code or Cowork, type: /thinkos-continue\n'
  printf '      · Or from a terminal:           scripts/thinkos-continue.sh\n\n'

  # Optional: multi-vault project creation
  n=$((n + 1))
  printf '  [%d] Optional: add a project or team vault\n' "$n"
  printf '      Personal Think OS setup is now complete. If you also want to\n'
  printf '      collaborate with a team on a shared knowledge base (project\n'
  printf '      decisions, specs, team activity log), you can add a project\n'
  printf '      vault anytime. It is a separate git-backed vault that lives\n'
  printf '      alongside your personal one — your personal log, identity,\n'
  printf '      and people notes stay strictly local.\n\n'
  printf '      To create a new project vault:\n'
  printf '        scripts/thinkos-vault.sh create-project <name>\n\n'
  printf '      To join an existing team vault from a git URL:\n'
  printf '        scripts/thinkos-vault.sh clone <git-url>\n\n'
  printf '      Or in your agent, run: /thinkos-vault\n\n'
  printf '      See docs/multi-vault-architecture.md for the full design.\n\n'

  printf '══════════════════════════════════════════════════════════════════════\n'
  printf '  At any point you can check progress with:\n'
  printf '    scripts/thinkos-state.sh where-am-i\n'
  printf '    scripts/thinkos-doctor.sh --deep --os-home %q --products %q\n' \
    "$VAULT_PATH" "$PRODUCTS_LIST"
  printf '    bash scripts/thinkos-vault.sh list\n\n'
}

# Helper: count how many manual steps will be shown to the user.
_count_manual_steps() {
  local n=0
  [[ ",$PRODUCTS_LIST," == *",claude-cowork,"* ]] && n=$((n + 1))
  if [[ -n "$BUNDLE" ]]; then
    local oauth_list
    oauth_list="$(_compute_oauth_pending)"
    [[ -n "$oauth_list" ]] && n=$((n + 1))
  fi
  n=$((n + 1))  # restart
  n=$((n + 1))  # Phase 2 continue
  n=$((n + 1))  # Optional: multi-vault project creation
  printf '%d' "$n"
}

# -----------------------------------------------------------------------------
# Main loop — supports back-to-start
# -----------------------------------------------------------------------------
welcome
while :; do
  step_vault
  step_products
  step_basic_memory
  step_bundle
  step_review
  case "$?" in
    0) apply; break ;;
    1) continue ;;
    2) printf '\n  Aborted. No changes made.\n\n'; exit 0 ;;
  esac
done
