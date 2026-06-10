#!/usr/bin/env bash
# render-instructions.sh — shared rendering helpers for Think OS scripts.
#
# Extracted from thinkos-setup.sh and thinkos-update.sh (WP-28) to eliminate
# ~80 lines of duplication that caused the v0.7.4 drift bug.
#
# Source this file from any script that needs to render the BEGIN/END THINK OS
# block. The sourcing script must have REPO_ROOT and DRY_RUN already set.
#
# Functions exported:
#   curated_instruction_files  — ordered list of always-on instruction file paths
#   render_template            — substitute {{OS_HOME}} in a markdown file
#   render_think_os_block      — render full Think OS block to stdout
#   install_marked_block       — write/replace a marked block in a target file

render_template() {
  local source_file="$1"
  python3 -c "
import sys, os
text = open(sys.argv[1]).read()
print(text.replace('{{OS_HOME}}', os.environ.get('OS_HOME', '')), end='')
" "$source_file"
}

# Returns the ordered list of curated always-on instruction files (one per line).
# The setup + update scripts concatenate these on top of the adapter-specific
# instructions when rendering the BEGIN/END THINK OS block.
curated_instruction_files() {
  local dir="$REPO_ROOT/templates/instructions"
  printf '%s\n' \
    "$dir/00-think-os-priority.md" \
    "$dir/05-global-rules.md" \
    "$dir/10-token-efficiency.md" \
    "$dir/20-skill-routing.md" \
    "$dir/30-think-os-write-targets.md" \
    "$dir/40-emergent-seeding.md" \
    "$dir/50-drift-detection.md" \
    "$dir/60-shared-mode.md" \
    "$dir/70-claude-ai-bridge.md"
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

  local tmp2
  tmp2="$(mktemp "$(dirname "$target")/.claude-md-XXXXXX")" || tmp2="$(mktemp)"
  # Capture any EXIT trap the caller already had so we can restore it instead
  # of clobbering it when our temp-file cleanup trap is removed.
  local prev_exit_trap
  prev_exit_trap="$(trap -p EXIT)"
  trap 'rm -f "$tmp" "$tmp2"' EXIT
  {
    cat "$tmp"
    printf '\n%s\n' "$begin"
    render_think_os_block "$source"
    printf '%s\n' "$end"
  } > "$tmp2"
  mv "$tmp2" "$target"
  rm -f "$tmp"
  if [[ -n "$prev_exit_trap" ]]; then
    eval "$prev_exit_trap"
  else
    trap - EXIT
  fi
}
