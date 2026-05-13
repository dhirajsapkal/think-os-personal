#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="think-os"
OS_HOME="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
PRODUCTS=""
INSTALL_BASIC_MEMORY=0
REGISTER_MCP=1
YES=0
DRY_RUN=0

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
  -h, --help                  Show this help

Example:
  scripts/thinkos-setup.sh --products claude-code,codex --install-basic-memory --yes
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
    render_template "$source"
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

  while IFS= read -r -d '' dir; do
    local rel="${dir#./}"
    [[ "$rel" == "." ]] && continue
    run mkdir -p "$OS_HOME/$rel"
  done < <(cd "$TEMPLATE_DIR" && find . -type d -print0)

  while IFS= read -r -d '' file; do
    local rel="${file#./}"
    local dest="$OS_HOME/$rel"
    if [[ -f "$dest" ]]; then
      log "Skip existing: $rel"
    else
      run mkdir -p "$(dirname "$dest")"
      run cp "$TEMPLATE_DIR/$rel" "$dest"
      log "Created: $rel"
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

install_claude_cowork() {
  log "Preparing Claude Cowork adapter"
  local out_dir="$HOME/.thinkos"
  local instructions="$out_dir/claude-cowork-instructions.md"
  local mcp_config="$out_dir/claude-cowork-mcp.txt"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Would write Cowork instructions to $instructions"
    return 0
  fi

  mkdir -p "$out_dir"
  render_template "$REPO_ROOT/adapters/claude-cowork/instructions.md" > "$instructions"
  cat > "$mcp_config" <<EOF
Name: Basic Memory
Command: basic-memory
Args: mcp --project $PROJECT_NAME
Working directory: $HOME
EOF

  log "Claude Cowork uses UI-managed MCP setup."
  log "MCP config saved to: $mcp_config"
  log "Instructions saved to: $instructions"
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$instructions"
    log "Cowork instructions copied to clipboard."
  fi
}

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
has_product "codex" && install_codex
has_product "claude-cowork" && install_claude_cowork

log
log "Setup steps complete. Run this next:"
log "  $REPO_ROOT/scripts/thinkos-doctor.sh --deep --os-home \"$OS_HOME\" --products \"$PRODUCTS\""
