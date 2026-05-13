#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="think-os"
OS_HOME="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
PRODUCTS=""
INSTALL_BASIC_MEMORY=0
REGISTER_MCP=1
YES=0
DRY_RUN=0
BUNDLE=""
BUNDLE_ITEMS=""

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-setup.sh [options]

Sets up the safe local pieces of Think OS:
- creates the vault folder
- copies missing template files
- optionally installs Basic Memory with uv
- registers/reindexes the Basic Memory project
- installs product-specific instructions for supported tools

Options:
  --os-home PATH              Live Think OS vault path (default: ~/ThinkOS/vault)
  --products LIST             Comma-separated products: claude-cowork,claude-code,codex,all
  --install-basic-memory      Install Basic Memory with uv if missing
  --skip-mcp                  Do not register MCPs in product CLIs
  --yes                       Non-interactive mode; accept safe defaults
  --dry-run                   Show what would happen without changing files
  --bundle PRESET             Install a curated bundle after product setup (pm|eng|design|ops|all)
  --bundle-items LIST         Comma-separated catalog ids to install (advanced)
  -h, --help                  Show this help

Examples:
  scripts/thinkos-setup.sh --products claude-code,codex --install-basic-memory --yes
  scripts/thinkos-setup.sh --products claude-code --bundle pm --yes
  scripts/thinkos-setup.sh --products claude-code --bundle-items slack,notion,granola --yes
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
    --install-basic-memory)
      INSTALL_BASIC_MEMORY=1
      shift
      ;;
    --skip-mcp)
      REGISTER_MCP=0
      shift
      ;;
    --yes)
      YES=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --bundle)
      BUNDLE="$2"
      shift 2
      ;;
    --bundle-items)
      BUNDLE_ITEMS="$2"
      shift 2
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

if [[ "$PRODUCTS" == "all" ]]; then
  PRODUCTS="claude-cowork,claude-code,codex"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/templates"

if [[ -z "$PRODUCTS" && -t 0 && "$YES" -eq 0 ]]; then
  read -r -p "Products to set up [claude-code,codex,claude-cowork]: " PRODUCTS
  PRODUCTS="${PRODUCTS:-claude-code,codex,claude-cowork}"
fi

if [[ -z "$PRODUCTS" ]]; then
  PRODUCTS="claude-code,codex"
fi

has_product() {
  local needle="$1"
  [[ ",$PRODUCTS," == *",$needle,"* ]]
}

log() {
  printf '%s\n' "$*"
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

render_template() {
  local source="$1"
  awk -v os_home="$OS_HOME" '{ gsub(/\{\{OS_HOME\}\}/, os_home); print }' "$source"
}

# Returns the ordered list of curated always-on instruction files (one per line).
# The setup + update scripts concatenate these on top of the adapter-specific
# instructions when rendering the BEGIN/END THINK OS block.
curated_instruction_files() {
  local dir="$REPO_ROOT/templates/instructions"
  printf '%s\n' \
    "$dir/00-think-os-priority.md" \
    "$dir/10-token-efficiency.md" \
    "$dir/20-skill-routing.md" \
    "$dir/30-think-os-write-targets.md"
}

# Render the full Think OS block to stdout: curated files (in order) followed
# by the adapter-specific instructions, each with `{{OS_HOME}}` substitution and
# separated by a section divider so the result reads as one document.
render_think_os_block() {
  local adapter_source="$1"
  local first=1
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [[ ! -f "$f" ]]; then
      continue
    fi
    if [[ "$first" -eq 0 ]]; then
      printf '\n---\n\n'
    fi
    render_template "$f"
    first=0
  done < <(curated_instruction_files)

  if [[ -n "$adapter_source" && -f "$adapter_source" ]]; then
    if [[ "$first" -eq 0 ]]; then
      printf '\n---\n\n'
    fi
    render_template "$adapter_source"
  fi
}

install_marked_block() {
  local target="$1"
  local begin="$2"
  local end="$3"
  local source="$4"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Would install/update Think OS block in $target"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  touch "$target"

  local tmp
  tmp="$(mktemp)"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "$target" > "$tmp"

  {
    cat "$tmp"
    printf '\n%s\n' "$begin"
    render_think_os_block "$source"
    printf '%s\n' "$end"
  } > "$target"

  rm -f "$tmp"
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

copy_templates() {
  log "Copying missing vault templates into $OS_HOME"
  run mkdir -p "$OS_HOME"

  # Subdirectories of templates/ that are NOT personal-vault content:
  #   instructions/ — curated agent-instruction stack (rendered into the
  #                   BEGIN/END THINK OS block, never copied into a vault)
  #   team/         — project-vault template skeleton (copied by
  #                   thinkos-vault.sh create-project, never into personal hubs)
  while IFS= read -r -d '' dir; do
    local rel="${dir#./}"
    [[ "$rel" == "." ]] && continue
    [[ "$rel" == "instructions" || "$rel" == instructions/* ]] && continue
    [[ "$rel" == "team" || "$rel" == team/* ]] && continue
    run mkdir -p "$OS_HOME/$rel"
  done < <(cd "$TEMPLATE_DIR" && find . -type d -print0)

  local created_verb="Created"
  [[ "$DRY_RUN" -eq 1 ]] && created_verb="Would create"

  while IFS= read -r -d '' file; do
    local rel="${file#./}"
    [[ "$rel" == instructions/* ]] && continue
    [[ "$rel" == team/* ]] && continue
    local dest="$OS_HOME/$rel"
    if [[ -f "$dest" ]]; then
      log "Skip existing: $rel"
    else
      run mkdir -p "$(dirname "$dest")"
      run cp "$TEMPLATE_DIR/$rel" "$dest"
      log "$created_verb: $rel"
    fi
  done < <(cd "$TEMPLATE_DIR" && find . -type f -print0)
}

ensure_basic_memory() {
  if command -v basic-memory >/dev/null 2>&1; then
    log "Basic Memory found: $(command -v basic-memory)"
    return 0
  fi

  if [[ "$INSTALL_BASIC_MEMORY" -ne 1 ]]; then
    log "Basic Memory is missing. Re-run with --install-basic-memory or install manually with: uv tool install basic-memory"
    return 1
  fi

  if ! command -v uv >/dev/null 2>&1; then
    log "uv is missing. Install it first: brew install uv"
    return 1
  fi

  log "Installing Basic Memory with uv"
  run uv tool install basic-memory
}

register_basic_memory_project() {
  if ! command -v basic-memory >/dev/null 2>&1; then
    log "Skipping Basic Memory project registration; basic-memory command is unavailable"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Would register Basic Memory project '$PROJECT_NAME' at $OS_HOME if missing"
    log "Would reindex Basic Memory project '$PROJECT_NAME'"
    return 0
  fi

  if basic-memory project ls --name "$PROJECT_NAME" >/dev/null 2>&1; then
    log "Basic Memory project '$PROJECT_NAME' already exists"
  else
    log "Registering Basic Memory project '$PROJECT_NAME'"
    # `--local --default` routes around Basic Memory's global cloud namespace — without these, re-adding a previously-removed project name fails with "Project already exists" and `project default` errors with "set to cloud mode but no credentials"
    run basic-memory project add "$PROJECT_NAME" "$OS_HOME" --local --default
  fi

  log "Reindexing Basic Memory project '$PROJECT_NAME'"
  run basic-memory reindex --project "$PROJECT_NAME"
}

install_claude_code() {
  log "Setting up Claude Code adapter"

  install_marked_block \
    "$HOME/.claude/CLAUDE.md" \
    "<!-- BEGIN THINK OS -->" \
    "<!-- END THINK OS -->" \
    "$REPO_ROOT/adapters/claude-code/instructions.md"

  run mkdir -p "$HOME/.claude/commands"
  for command_file in "$REPO_ROOT"/adapters/claude-code/commands/*.md; do
    [[ "$(basename "$command_file")" == "README.md" ]] && continue
    run cp "$command_file" "$HOME/.claude/commands/"
  done

  if [[ "$REGISTER_MCP" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "Would register Claude Code basic-memory MCP at user scope if missing"
      return 0
    fi

    if command -v claude >/dev/null 2>&1; then
      if claude mcp list 2>/dev/null | grep -q "basic-memory"; then
        log "Claude Code MCP already includes basic-memory"
      else
        run claude mcp add basic-memory --scope user -- basic-memory mcp --project "$PROJECT_NAME"
      fi
    else
      log "Claude Code CLI not found; installed instructions/commands, but skipped MCP registration"
    fi
  fi
}

install_codex() {
  log "Setting up Codex adapter"

  install_marked_block \
    "$HOME/.codex/AGENTS.md" \
    "<!-- BEGIN THINK OS -->" \
    "<!-- END THINK OS -->" \
    "$REPO_ROOT/adapters/codex/AGENTS.md"

  if [[ "$REGISTER_MCP" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "Would register Codex basic-memory MCP if missing"
      return 0
    fi

    if command -v codex >/dev/null 2>&1; then
      if codex mcp get basic-memory >/dev/null 2>&1; then
        log "Codex MCP already includes basic-memory"
      else
        run codex mcp add basic-memory -- basic-memory mcp --project "$PROJECT_NAME"
      fi
    else
      log "Codex CLI not found; installed AGENTS.md block, but skipped MCP registration"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Install manifest writer
# ---------------------------------------------------------------------------
# Records what this run installed so `thinkos-uninstall.sh` has a precise list
# to undo. Written at ~/.thinkos/install-manifest.json after a successful apply.
#
# The manifest is best-effort: it records intent based on the products/flags
# that this invocation acted on. The uninstaller still falls back to repo
# enumeration when fields are missing (e.g. for installs done before this
# was added).
_write_install_manifest() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Would write install manifest to $HOME/.thinkos/install-manifest.json"
    return 0
  fi

  local manifest="$HOME/.thinkos/install-manifest.json"
  mkdir -p "$HOME/.thinkos"

  # Build the lists in env vars; python3 reads them and writes JSON atomically.
  local files_list=""
  local cc_mcps=""
  local codex_mcps=""

  if has_product "claude-code"; then
    files_list+="$HOME/.claude/CLAUDE.md (block injected)"$'\n'
    if [[ -d "$REPO_ROOT/adapters/claude-code/commands" ]]; then
      while IFS= read -r -d '' command_file; do
        local base
        base="$(basename "$command_file")"
        [[ "$base" == "README.md" ]] && continue
        files_list+="$HOME/.claude/commands/$base"$'\n'
      done < <(find "$REPO_ROOT/adapters/claude-code/commands" -maxdepth 1 -name '*.md' -type f -print0)
    fi
    if [[ "$REGISTER_MCP" -eq 1 ]]; then
      cc_mcps+="basic-memory"$'\n'
    fi
    # Bundle-added MCPs (best-effort: enumerate the resolved list).
    if [[ -n "$BUNDLE" || -n "$BUNDLE_ITEMS" ]]; then
      local resolved=""
      if source "$REPO_ROOT/scripts/lib/catalog.sh" 2>/dev/null; then
        if [[ -n "$BUNDLE" ]]; then
          resolved="$(catalog_resolve_preset "$BUNDLE" 2>/dev/null | catalog_filter_by_target claude_code)"
        elif [[ -n "$BUNDLE_ITEMS" ]]; then
          resolved="$(printf '%s' "$BUNDLE_ITEMS" | tr ',' '\n' | catalog_filter_by_target claude_code)"
        fi
        while IFS= read -r bundle_id; do
          [[ -z "$bundle_id" ]] && continue
          local mcp_name
          mcp_name="$(catalog_get_field "$bundle_id" "claude_code.mcp_name" 2>/dev/null)"
          [[ -n "$mcp_name" ]] && cc_mcps+="$mcp_name"$'\n'
        done < <(printf '%s\n' "$resolved")
      fi
    fi
  fi

  if has_product "codex"; then
    files_list+="$HOME/.codex/AGENTS.md (block injected)"$'\n'
    if [[ "$REGISTER_MCP" -eq 1 ]]; then
      codex_mcps+="basic-memory"$'\n'
    fi
  fi

  if has_product "claude-cowork"; then
    files_list+="$HOME/.thinkos/claude-cowork-instructions.md"$'\n'
    files_list+="$HOME/.thinkos/claude-cowork-mcp.txt"$'\n'
    if [[ -n "$BUNDLE" || -n "$BUNDLE_ITEMS" ]]; then
      files_list+="$HOME/.thinkos/claude-cowork-bundle.json"$'\n'
    fi
  fi

  # Plugins list (bundle-installed) — for display in uninstaller, since plugin
  # removal requires interactive Claude Code anyway.
  local plugins_list=""
  if has_product "claude-code" && [[ -n "$BUNDLE" || -n "$BUNDLE_ITEMS" ]]; then
    if source "$REPO_ROOT/scripts/lib/catalog.sh" 2>/dev/null; then
      local plugin_resolved=""
      if [[ -n "$BUNDLE" ]]; then
        plugin_resolved="$(catalog_resolve_preset "$BUNDLE" 2>/dev/null | catalog_filter_by_target claude_code)"
      elif [[ -n "$BUNDLE_ITEMS" ]]; then
        plugin_resolved="$(printf '%s' "$BUNDLE_ITEMS" | tr ',' '\n' | catalog_filter_by_target claude_code)"
      fi
      while IFS= read -r p_id; do
        [[ -z "$p_id" ]] && continue
        local p_kind p_slug p_mp
        p_kind="$(catalog_kind "$p_id" "claude_code" 2>/dev/null)"
        if [[ "$p_kind" == "plugin" || "$p_kind" == "skill_bundle" ]]; then
          p_slug="$(catalog_get_field "$p_id" "claude_code.plugin" 2>/dev/null)"
          p_mp="$(catalog_get_field "$p_id" "claude_code.marketplace" 2>/dev/null)"
          if [[ -n "$p_slug" && -n "$p_mp" ]]; then
            plugins_list+="${p_slug}|${p_mp}"$'\n'
          fi
        fi
      done < <(printf '%s\n' "$plugin_resolved")
    fi
  fi

  FILES_LIST="$files_list" \
  CC_MCPS="$cc_mcps" \
  CODEX_MCPS="$codex_mcps" \
  PLUGINS_LIST="$plugins_list" \
  VAULT_PATH="$OS_HOME" \
  BM_PROJECT="$PROJECT_NAME" \
  PRODUCTS_ENV="$PRODUCTS" \
  BUNDLE_ENV="$BUNDLE" \
  MANIFEST_FILE="$manifest" \
  python3 - <<'PYEOF'
import json, os, sys, tempfile, datetime

def split_lines(s):
    return [ln.strip() for ln in (s or "").splitlines() if ln.strip()]

manifest_path = os.environ["MANIFEST_FILE"]
files = split_lines(os.environ.get("FILES_LIST", ""))
cc_mcps = split_lines(os.environ.get("CC_MCPS", ""))
codex_mcps = split_lines(os.environ.get("CODEX_MCPS", ""))
plugins_raw = split_lines(os.environ.get("PLUGINS_LIST", ""))
plugins = []
for line in plugins_raw:
    if "|" in line:
        slug, mp = line.split("|", 1)
        plugins.append({"plugin": slug, "marketplace": mp})

products = [p for p in (os.environ.get("PRODUCTS_ENV") or "").split(",") if p]

manifest = {
    "version": 1,
    "installed_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "vault_path": os.environ.get("VAULT_PATH", ""),
    "bm_project": os.environ.get("BM_PROJECT", ""),
    "bundle": os.environ.get("BUNDLE_ENV", "") or None,
    "products": products,
    "files": files,
    "mcps": {
        "claude-code": cc_mcps,
        "codex": codex_mcps,
    },
    "plugins": plugins,
}

os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(manifest_path),
                            prefix=".install-manifest-", suffix=".tmp")
try:
    with os.fdopen(fd, "w") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=False)
        fh.write("\n")
    os.replace(tmp, manifest_path)
except Exception:
    try: os.unlink(tmp)
    except OSError: pass
    raise

print("Wrote install manifest: " + manifest_path)
PYEOF
}

install_claude_cowork() {
  log "Preparing Claude Cowork adapter"
  local out_dir="$HOME/.thinkos"
  local instructions="$out_dir/claude-cowork-instructions.md"
  local mcp_config="$out_dir/claude-cowork-mcp.txt"
  local bundle_json="$out_dir/claude-cowork-bundle.json"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Would write Cowork instructions to $instructions"
    if [[ -n "$BUNDLE" || -n "$BUNDLE_ITEMS" ]]; then
      log "Would write Cowork bundle handoff to $bundle_json"
    fi
    return 0
  fi

  mkdir -p "$out_dir"
  # Cowork doesn't have BEGIN/END markers in a global file — the user pastes the
  # whole block into Cowork's personalization UI. Still render the full curated
  # stack + Cowork adapter so the user gets the same always-on guidance.
  render_think_os_block "$REPO_ROOT/adapters/claude-cowork/instructions.md" > "$instructions"
  cat > "$mcp_config" <<EOF
Name: Basic Memory
Command: basic-memory
Args: mcp --project $PROJECT_NAME
Working directory: $HOME
EOF

  # Write bundle handoff JSON if a bundle or custom item list was given.
  # The Cowork agent reads this file so it doesn't have to re-ask the user.
  if [[ -n "$BUNDLE" ]]; then
    # Resolve preset to Cowork-available ids via the catalog lib.
    local resolved_items=""
    if source "$REPO_ROOT/scripts/lib/catalog.sh" 2>/dev/null; then
      resolved_items=$(catalog_resolve_preset "$BUNDLE" 2>/dev/null \
        | catalog_filter_by_target cowork \
        | tr '\n' ',' \
        | sed 's/,$//')
    fi
    local preset_label="$BUNDLE"
    cat > "$bundle_json" <<EOF
{
  "preset": "$preset_label",
  "items": [$(echo "$resolved_items" | sed 's/\([^,][^,]*\)/"\1"/g')]
}
EOF
    log "Cowork bundle handoff written to: $bundle_json (preset: $BUNDLE)"
  elif [[ -n "$BUNDLE_ITEMS" ]]; then
    # Custom item list passed directly — no preset resolution needed.
    local quoted_items
    quoted_items=$(echo "$BUNDLE_ITEMS" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/\(.*\)/"\1"/' | tr '\n' ',' | sed 's/,$//')
    cat > "$bundle_json" <<EOF
{
  "preset": "custom",
  "items": [$quoted_items]
}
EOF
    log "Cowork bundle handoff written to: $bundle_json (custom items)"
  fi

  log "Claude Cowork uses UI-managed MCP setup."
  log "MCP config saved to: $mcp_config"
  log "Instructions saved to: $instructions"
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$instructions"
    log "Cowork instructions copied to clipboard."
  fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  log "Think OS setup scripts are macOS-only for the early alpha."
  log "Detected: $(uname -s). Linux/Windows support is not yet wired."
  log "If you want to proceed manually, see docs/setup-basic-memory.md and adapters/<your-product>/README.md."
  exit 2
fi

log "Think OS setup"
log "Vault: $OS_HOME"
log "Products: $PRODUCTS"

if [[ "$(uname -s)" == "Darwin" ]] && is_protected_macos_path; then
  log "Note: $OS_HOME is under a macOS protected folder. Host apps may need Files/Folders or Full Disk Access."
  log "Recommended low-friction path: $HOME/ThinkOS/vault"
fi

copy_templates
ensure_basic_memory
register_basic_memory_project

has_product "claude-code" && install_claude_code

if has_product "claude-code" && [[ -n "$BUNDLE" || -n "$BUNDLE_ITEMS" ]]; then
  bundle_args=()
  [[ -n "$BUNDLE" ]] && bundle_args+=(--preset "$BUNDLE")
  [[ -n "$BUNDLE_ITEMS" ]] && bundle_args+=(--items "$BUNDLE_ITEMS")
  [[ "$YES" -eq 1 ]] && bundle_args+=(--yes)
  [[ "$DRY_RUN" -eq 1 ]] && bundle_args+=(--dry-run)
  "$REPO_ROOT/scripts/thinkos-install-bundle.sh" --target claude-code "${bundle_args[@]}"
elif [[ -n "$BUNDLE" || -n "$BUNDLE_ITEMS" ]]; then
  log "Warning: --bundle/--bundle-items given but claude-code not in --products; bundle install skipped."
fi

has_product "codex" && install_codex
has_product "claude-cowork" && install_claude_cowork

_write_install_manifest

log
log "Setup steps complete. Run this next:"
log "  $REPO_ROOT/scripts/thinkos-doctor.sh --deep --os-home \"$OS_HOME\" --products \"$PRODUCTS\""

if has_product "claude-cowork"; then
  log
  log "============================================================"
  log "  NOW DO THIS IN COWORK"
  log "============================================================"
  log "Cowork's MCP is UI-managed — the script can't register it for you."
  log
  log "1. Open Claude Cowork → Settings → Connectors / MCP Servers"
  log "2. Add a custom MCP server using the values in:"
  log "     $HOME/.thinkos/claude-cowork-mcp.txt"
  log "3. Paste the personalization block from:"
  log "     $HOME/.thinkos/claude-cowork-instructions.md"
  log "   (already on your clipboard if pbcopy ran above)"
  log "4. Restart Cowork (quit and reopen — not just close the window)"
  log
  log "5. Install your plugin/connector bundle:"
  log "   In Cowork, run the /thinkos-bundle slash command (or ask the"
  log "   agent to follow adapters/claude-cowork/commands/thinkos-bundle.md)."
  if [[ -n "$BUNDLE" || -n "$BUNDLE_ITEMS" ]]; then
    log "   Your bundle selection has been saved to:"
    log "     $HOME/.thinkos/claude-cowork-bundle.json"
    log "   The Cowork agent will read that file and skip re-asking you."
  fi
  log "============================================================"
fi
