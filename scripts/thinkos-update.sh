#!/usr/bin/env bash
set -euo pipefail

# thinkos-update.sh — re-apply Think OS global agent instructions.
#
# Pulls latest curated instructions and adapter content from this repo and
# rewrites the BEGIN/END THINK OS block in each installed product's instruction
# file. Does NOT re-run Basic Memory install, MCP registration, template copy,
# or bundle install — those are install-time operations.

PROJECT_NAME="think-os"
PULL=0
PRODUCTS=""
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-update.sh [options]

Pulls the latest Think OS curated instructions from this repo and re-applies
the global agent instruction block (BEGIN/END THINK OS) for each installed
product. Use this when curated instructions change or after `git pull`.

Options:
  --pull             Run `git pull --ff-only` in this repo before reapplying.
                     Requires this directory to be a git checkout with a clean
                     working tree (otherwise the pull is aborted).
  --skip-pull        (default) Just reapply current local instructions.
  --products LIST    Comma-separated subset to update (claude-code,codex,
                     claude-cowork,all). Default: auto-detect installed.
  --dry-run          Show what would change without writing.
  -h, --help         Show this help

What gets re-applied:
  - The BEGIN/END THINK OS block in:
      ~/.claude/CLAUDE.md             (Claude Code)
      ~/.codex/AGENTS.md              (Codex)
      ~/.thinkos/claude-cowork-instructions.md  (Cowork; user re-pastes)
  - Slash commands in ~/.claude/commands/ (overwrites older versions)

What this does NOT do:
  - Re-install Basic Memory
  - Re-register MCP servers
  - Copy vault templates
  - Install bundles / plugins
  - Touch your vault content
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pull)
      PULL=1
      shift
      ;;
    --skip-pull)
      PULL=0
      shift
      ;;
    --products)
      PRODUCTS="$2"
      shift 2
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OS_HOME="${THINKOS_HOME:-$HOME/ThinkOS/vault}"

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

curated_instruction_files() {
  local dir="$REPO_ROOT/templates/instructions"
  printf '%s\n' \
    "$dir/00-think-os-priority.md" \
    "$dir/05-global-rules.md" \
    "$dir/10-token-efficiency.md" \
    "$dir/20-skill-routing.md" \
    "$dir/30-think-os-write-targets.md"
}

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
    log "Would refresh THINK OS block in $target"
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

maybe_git_pull() {
  if [[ "$PULL" -ne 1 ]]; then
    return 0
  fi

  if [[ ! -d "$REPO_ROOT/.git" ]]; then
    log "ERROR: --pull requested but $REPO_ROOT is not a git checkout."
    exit 2
  fi

  # Refuse to pull over uncommitted local changes — protect the user's edits.
  if ! git -C "$REPO_ROOT" diff --quiet || ! git -C "$REPO_ROOT" diff --cached --quiet; then
    log "ERROR: Uncommitted local changes in $REPO_ROOT."
    log "       Commit or stash them before running with --pull."
    log "       (Run again with --skip-pull to apply local content as-is.)"
    exit 1
  fi

  log "Pulling latest from origin"
  run git -C "$REPO_ROOT" pull --ff-only
}

# Detect which products are installed. We use the marker file each product
# writes during setup so we don't accidentally clobber a product the user
# never installed.
detect_installed_products() {
  local found=""
  if [[ -f "$HOME/.claude/CLAUDE.md" ]] && grep -q "BEGIN THINK OS" "$HOME/.claude/CLAUDE.md" 2>/dev/null; then
    found="${found:+$found,}claude-code"
  fi
  if [[ -f "$HOME/.codex/AGENTS.md" ]] && grep -q "BEGIN THINK OS" "$HOME/.codex/AGENTS.md" 2>/dev/null; then
    found="${found:+$found,}codex"
  fi
  if [[ -f "$HOME/.thinkos/claude-cowork-instructions.md" ]]; then
    found="${found:+$found,}claude-cowork"
  fi
  printf '%s' "$found"
}

has_product() {
  local needle="$1"
  [[ ",$PRODUCTS," == *",$needle,"* ]]
}

update_claude_code() {
  log "Refreshing Claude Code instructions"
  install_marked_block \
    "$HOME/.claude/CLAUDE.md" \
    "<!-- BEGIN THINK OS -->" \
    "<!-- END THINK OS -->" \
    "$REPO_ROOT/adapters/claude-code/instructions.md"

  log "Refreshing Claude Code slash commands at ~/.claude/commands/"
  run mkdir -p "$HOME/.claude/commands"
  local command_file
  for command_file in "$REPO_ROOT"/adapters/claude-code/commands/*.md; do
    [[ "$(basename "$command_file")" == "README.md" ]] && continue
    run cp "$command_file" "$HOME/.claude/commands/"
  done
}

update_codex() {
  log "Refreshing Codex instructions"
  install_marked_block \
    "$HOME/.codex/AGENTS.md" \
    "<!-- BEGIN THINK OS -->" \
    "<!-- END THINK OS -->" \
    "$REPO_ROOT/adapters/codex/AGENTS.md"
}

update_claude_cowork() {
  log "Refreshing Cowork personalization block"
  local out_dir="$HOME/.thinkos"
  local instructions="$out_dir/claude-cowork-instructions.md"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Would rewrite $instructions"
    return 0
  fi

  mkdir -p "$out_dir"
  render_think_os_block "$REPO_ROOT/adapters/claude-cowork/instructions.md" > "$instructions"
  log "Cowork instructions rewritten: $instructions"
  log "  Paste this into Cowork → Settings → Personalization and restart Cowork."
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$instructions"
    log "  Already copied to clipboard."
  fi
}

maybe_git_pull

if [[ -z "$PRODUCTS" ]]; then
  PRODUCTS="$(detect_installed_products)"
  if [[ -z "$PRODUCTS" ]]; then
    log "No installed Think OS products detected."
    log "Run scripts/thinkos-setup.sh first to install at least one product."
    exit 0
  fi
  log "Detected installed products: $PRODUCTS"
fi

if [[ "$PRODUCTS" == "all" ]]; then
  PRODUCTS="claude-code,codex,claude-cowork"
fi

UPDATED_COUNT=0

if has_product "claude-code"; then
  update_claude_code
  UPDATED_COUNT=$((UPDATED_COUNT + 1))
fi
if has_product "codex"; then
  update_codex
  UPDATED_COUNT=$((UPDATED_COUNT + 1))
fi
if has_product "claude-cowork"; then
  update_claude_cowork
  UPDATED_COUNT=$((UPDATED_COUNT + 1))
fi

log
log "Updated: $UPDATED_COUNT product(s)."
if [[ "$DRY_RUN" -eq 1 ]]; then
  log "(Dry run — no files were modified.)"
fi
