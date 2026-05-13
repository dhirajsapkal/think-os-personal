#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-uninstall.sh — Think OS uninstaller
# =============================================================================
# Reverses what thinkos-setup.sh, thinkos-install-bundle.sh, and
# thinkos-vault.sh install on a user's machine. By default it preserves user
# data (vault contents) and leaves bundle MCPs registered — opt in with flags
# to be more aggressive.
#
# Plan first, act second. Always prints a numbered plan and requires a typed
# "yes" before mutating anything (unless --yes is passed).
#
# Reads ~/.thinkos/install-manifest.json as the authoritative source of what
# to undo. Falls back to enumerating from this repo when the manifest is
# missing (older installs).
#
# Bash 3.2 compatible (macOS default). No associative arrays.
# =============================================================================
set -uo pipefail

# ---------------------------------------------------------------------------
# Defaults / flags
# ---------------------------------------------------------------------------
DRY_RUN=0
REMOVE_VAULT=0
REMOVE_MCPS=0
REMOVE_BASIC_MEMORY=0
YES=0
MANIFEST_OVERRIDE=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

THINKOS_DIR="$HOME/.thinkos"
DEFAULT_MANIFEST="$THINKOS_DIR/install-manifest.json"
MANIFEST_PATH=""

# Will be filled by manifest load OR repo fallback enumeration.
M_VAULT_PATH=""
M_BM_PROJECT="think-os"
M_PRODUCTS=""
M_FILES=""            # newline-separated raw entries (may include " (block injected)")
M_CC_MCPS=""          # newline-separated
M_PLUGINS=""          # newline-separated "slug|marketplace"
M_BUNDLE=""
M_SOURCE=""           # "manifest" or "fallback"

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: scripts/thinkos-uninstall.sh [options]

Reverses Think OS install steps. Plans first, asks before mutating. Preserves
user data (vault contents) and bundle MCPs by default.

Options:
  --dry-run             Show what would be removed; don't touch anything.
  --keep-vault          (default) Leave the vault folder alone.
  --remove-vault        Also delete the vault directory. Requires --yes.
  --keep-mcps           (default) Leave bundle MCPs registered.
  --remove-mcps         Also unregister bundle MCPs (slack, gmail, etc.).
  --keep-basic-memory   (default) Leave Basic Memory project + binary.
  --remove-basic-memory Also unregister BM project and offer to uninstall the
                        BM binary.
  --all                 Equivalent to --remove-vault --remove-mcps
                        --remove-basic-memory. Requires explicit "yes" prompt.
  --yes                 Skip confirmation prompts (DANGEROUS; required for
                        --remove-* flags).
  --manifest PATH       Read a non-default manifest path.
  -h, --help            Show this help and exit.

Default manifest path: ~/.thinkos/install-manifest.json
EOF
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --keep-vault) REMOVE_VAULT=0; shift ;;
    --remove-vault) REMOVE_VAULT=1; shift ;;
    --keep-mcps) REMOVE_MCPS=0; shift ;;
    --remove-mcps) REMOVE_MCPS=1; shift ;;
    --keep-basic-memory) REMOVE_BASIC_MEMORY=0; shift ;;
    --remove-basic-memory) REMOVE_BASIC_MEMORY=1; shift ;;
    --all)
      REMOVE_VAULT=1
      REMOVE_MCPS=1
      REMOVE_BASIC_MEMORY=1
      shift
      ;;
    --yes) YES=1; shift ;;
    --manifest)
      MANIFEST_OVERRIDE="${2:-}"
      if [ -z "$MANIFEST_OVERRIDE" ]; then
        printf 'Error: --manifest requires a path\n' >&2
        exit 2
      fi
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
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
log()   { printf '%s\n' "$*"; }
err()   { printf '%s\n' "$*" >&2; }
hdr()   { printf '\n=== %s ===\n' "$*"; }

# Step counter used by the planning printout.
STEP=0
plan_step() {
  STEP=$((STEP + 1))
  printf '%2d. %s\n' "$STEP" "$*"
}

# ---------------------------------------------------------------------------
# Manifest loading
# ---------------------------------------------------------------------------
_load_manifest() {
  local path="$1"
  if [ ! -f "$path" ]; then
    return 1
  fi

  # Validate + extract fields with python3. Print as a small env-var dump that
  # we eval back into the shell.
  local extracted
  extracted="$(MANIFEST_PATH="$path" python3 - <<'PYEOF' 2>/dev/null
import json, os, sys, shlex

p = os.environ["MANIFEST_PATH"]
try:
    with open(p) as fh:
        m = json.load(fh)
except Exception as e:
    print("MANIFEST_OK=0", flush=True)
    sys.exit(0)

if not isinstance(m, dict) or m.get("version") != 1:
    print("MANIFEST_OK=0", flush=True)
    sys.exit(0)

def lines(lst):
    if not isinstance(lst, list):
        return ""
    return "\n".join(str(x) for x in lst)

def shquote(s):
    return shlex.quote(str(s))

vault = m.get("vault_path", "") or ""
bm = m.get("bm_project", "") or "think-os"
products = ",".join(m.get("products", []) or [])
files = lines(m.get("files", []))
cc = lines((m.get("mcps", {}) or {}).get("claude-code", []))
plugins = m.get("plugins", []) or []
plugin_lines = []
for pl in plugins:
    if isinstance(pl, dict):
        slug = pl.get("plugin", "")
        mp = pl.get("marketplace", "")
        if slug and mp:
            plugin_lines.append(f"{slug}|{mp}")
plugins_s = "\n".join(plugin_lines)
bundle = m.get("bundle", "") or ""

print("MANIFEST_OK=1")
print("M_VAULT_PATH=" + shquote(vault))
print("M_BM_PROJECT=" + shquote(bm))
print("M_PRODUCTS=" + shquote(products))
print("M_FILES=" + shquote(files))
print("M_CC_MCPS=" + shquote(cc))
print("M_PLUGINS=" + shquote(plugins_s))
print("M_BUNDLE=" + shquote(bundle))
PYEOF
)"

  if [ -z "$extracted" ]; then
    return 1
  fi

  # Eval the assignments. The python output is shell-safe via shlex.quote.
  eval "$extracted"

  if [ "${MANIFEST_OK:-0}" != "1" ]; then
    return 1
  fi

  M_SOURCE="manifest"
  return 0
}

# ---------------------------------------------------------------------------
# Fallback enumeration when no manifest exists
# ---------------------------------------------------------------------------
_fallback_enumerate() {
  M_SOURCE="fallback"

  # Vault: try the v0 default and THINKOS_HOME env.
  if [ -n "${THINKOS_HOME:-}" ]; then
    M_VAULT_PATH="$THINKOS_HOME"
  elif [ -d "$HOME/ThinkOS/vault" ]; then
    M_VAULT_PATH="$HOME/ThinkOS/vault"
  else
    M_VAULT_PATH=""
  fi

  M_BM_PROJECT="think-os"

  # Products: infer from on-disk artifacts (Claude Code only).
  local prods=""
  if [ -f "$HOME/.claude/CLAUDE.md" ] && grep -q '<!-- BEGIN THINK OS -->' "$HOME/.claude/CLAUDE.md" 2>/dev/null; then
    prods="claude-code"
  fi
  M_PRODUCTS="$prods"

  # Files: enumerate by walking the repo's adapters.
  local files=""
  if [ -f "$HOME/.claude/CLAUDE.md" ] && grep -q '<!-- BEGIN THINK OS -->' "$HOME/.claude/CLAUDE.md" 2>/dev/null; then
    files+="$HOME/.claude/CLAUDE.md (block injected)"$'\n'
    if [ -d "$REPO_ROOT/adapters/claude-code/commands" ]; then
      while IFS= read -r -d '' cf; do
        local base; base="$(basename "$cf")"
        [ "$base" = "README.md" ] && continue
        # Only list it as a potential target if it's on disk.
        if [ -f "$HOME/.claude/commands/$base" ]; then
          files+="$HOME/.claude/commands/$base"$'\n'
        fi
      done < <(find "$REPO_ROOT/adapters/claude-code/commands" -maxdepth 1 -name '*.md' -type f -print0)
    fi
  fi
  M_FILES="$files"

  # MCPs: assume basic-memory if Claude Code was set up.
  local cc=""
  if [ -f "$HOME/.claude/CLAUDE.md" ] && grep -q '<!-- BEGIN THINK OS -->' "$HOME/.claude/CLAUDE.md" 2>/dev/null; then
    cc="basic-memory"$'\n'
  fi

  # In fallback mode we ALSO want to consider bundle MCPs from the catalog,
  # but only if a bundle marker file exists. We don't try to read which MCPs
  # are actually registered with claude (too brittle); instead we offer them
  # all from the catalog and let the actual `claude mcp remove` step skip
  # missing ones.
  if [ -f "$HOME/.thinkos/claude-code-bundle.txt" ]; then
    local saved_preset
    saved_preset="$(cat "$HOME/.thinkos/claude-code-bundle.txt" 2>/dev/null | head -1 | tr -d '[:space:]')"
    M_BUNDLE="$saved_preset"
    if [ -n "$saved_preset" ] && [ -f "$REPO_ROOT/scripts/lib/catalog.sh" ]; then
      # Source catalog lib; collect mcp_names + plugins.
      # shellcheck source=scripts/lib/catalog.sh
      if . "$REPO_ROOT/scripts/lib/catalog.sh" 2>/dev/null; then
        local resolved
        resolved="$(catalog_resolve_preset "$saved_preset" 2>/dev/null | catalog_filter_by_target claude_code)"
        local plugin_lines=""
        while IFS= read -r bid; do
          [ -z "$bid" ] && continue
          local k mn slug mp
          k="$(catalog_kind "$bid" "claude_code" 2>/dev/null)"
          if [ "$k" = "mcp_remote" ] || [ "$k" = "mcp_stdio" ]; then
            mn="$(catalog_get_field "$bid" "claude_code.mcp_name" 2>/dev/null)"
            [ -n "$mn" ] && cc+="$mn"$'\n'
          elif [ "$k" = "plugin" ] || [ "$k" = "skill_bundle" ]; then
            slug="$(catalog_get_field "$bid" "claude_code.plugin" 2>/dev/null)"
            mp="$(catalog_get_field "$bid" "claude_code.marketplace" 2>/dev/null)"
            if [ -n "$slug" ] && [ -n "$mp" ]; then
              plugin_lines+="${slug}|${mp}"$'\n'
            fi
          fi
        done < <(printf '%s\n' "$resolved")
        M_PLUGINS="$plugin_lines"
      fi
    fi
  fi

  M_CC_MCPS="$cc"
}

# ---------------------------------------------------------------------------
# Pre-action helpers
# ---------------------------------------------------------------------------
_has_product() {
  case ",$M_PRODUCTS," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Return 0 if the given mcp name appears to be the "basic-memory" MCP.
_is_bm_mcp() {
  [ "$1" = "basic-memory" ]
}

# Build verb based on dry-run.
_verb() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'Would %s' "$1"
  else
    printf '%s' "$2"
  fi
}

# ---------------------------------------------------------------------------
# Phase: build the plan
# ---------------------------------------------------------------------------
# Categorized plan output. We print it before any action.
_print_plan() {
  hdr "Uninstall plan"
  log "Source:    $M_SOURCE"
  log "Manifest:  ${MANIFEST_PATH:-<none>}"
  log "Vault:     ${M_VAULT_PATH:-<unknown>}"
  log "BM project: $M_BM_PROJECT"
  log "Products:  ${M_PRODUCTS:-<unknown>}"
  log "Flags:     dry-run=$DRY_RUN remove-vault=$REMOVE_VAULT remove-mcps=$REMOVE_MCPS remove-basic-memory=$REMOVE_BASIC_MEMORY"
  log ""
  log "Will do the following, in order:"
  log ""

  STEP=0

  # 1. CLAUDE.md block
  if printf '%s\n' "$M_FILES" | grep -q '/\.claude/CLAUDE\.md '; then
    plan_step "Remove Think OS block from $HOME/.claude/CLAUDE.md (preserves other content)."
  fi

  # 2. Slash commands
  local cmd_count=0
  while IFS= read -r line; do
    case "$line" in
      "$HOME/.claude/commands/"*.md) cmd_count=$((cmd_count + 1)) ;;
    esac
  done < <(printf '%s\n' "$M_FILES")
  if [ "$cmd_count" -gt 0 ]; then
    plan_step "Remove $cmd_count Think OS slash command file(s) from $HOME/.claude/commands/."
  fi

  # 3. basic-memory MCP in claude-code
  local cc_bm=0 cc_bundle=0
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    if _is_bm_mcp "$m"; then cc_bm=1; else cc_bundle=$((cc_bundle + 1)); fi
  done < <(printf '%s\n' "$M_CC_MCPS")

  if [ "$cc_bm" -eq 1 ]; then
    if [ "$REMOVE_BASIC_MEMORY" -eq 1 ]; then
      plan_step "Unregister 'basic-memory' MCP from Claude Code (claude mcp remove basic-memory --scope user)."
    else
      plan_step "Skip Claude Code 'basic-memory' MCP removal (pass --remove-basic-memory to unregister)."
    fi
  fi

  # 4. Bundle MCPs
  if [ "$cc_bundle" -gt 0 ]; then
    if [ "$REMOVE_MCPS" -eq 1 ]; then
      local bundle_names=""
      while IFS= read -r m; do
        [ -z "$m" ] && continue
        if ! _is_bm_mcp "$m"; then
          bundle_names+="$m, "
        fi
      done < <(printf '%s\n' "$M_CC_MCPS")
      bundle_names="${bundle_names%, }"
      plan_step "Unregister bundle MCPs from Claude Code: $bundle_names."
    else
      plan_step "Skip bundle MCP removal ($cc_bundle MCPs; pass --remove-mcps to unregister)."
    fi
  fi

  # 5. Basic Memory project registration
  if [ "$REMOVE_BASIC_MEMORY" -eq 1 ]; then
    plan_step "Unregister Basic Memory project '$M_BM_PROJECT' (basic-memory project remove)."
    plan_step "Optionally uninstall the basic-memory binary (prompted)."
  else
    plan_step "Skip Basic Memory project '$M_BM_PROJECT' removal (pass --remove-basic-memory to unregister)."
  fi

  # 6. ~/.thinkos state files
  plan_step "Remove ~/.thinkos state files (vaults.json, active-vault, claude-code-bundle.txt, install-manifest.json) and the ~/.thinkos directory if it ends up empty."

  # 7. Vault directory
  if [ -n "$M_VAULT_PATH" ]; then
    if [ "$REMOVE_VAULT" -eq 1 ]; then
      plan_step "DELETE vault directory: $M_VAULT_PATH  (user data will be lost!)"
    else
      plan_step "Preserve vault directory: $M_VAULT_PATH  (use --remove-vault to delete it)."
    fi
  fi

  # 8. Plugin removal instructions
  local plugin_count=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    plugin_count=$((plugin_count + 1))
  done < <(printf '%s\n' "$M_PLUGINS")
  if [ "$plugin_count" -gt 0 ]; then
    plan_step "Print interactive /plugin remove instructions for $plugin_count Claude Code plugin(s) (no CLI auto-removal available)."
  fi

  log ""
}

# ---------------------------------------------------------------------------
# Phase: confirm
# ---------------------------------------------------------------------------
_confirm() {
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] Skipping confirmation; nothing will be touched."
    return 0
  fi
  if [ "$YES" -eq 1 ]; then
    log "--yes specified; skipping confirmation prompt."
    return 0
  fi

  if [ "$REMOVE_VAULT" -eq 1 ] && [ -n "$M_VAULT_PATH" ]; then
    log "WARNING: --remove-vault will permanently delete:"
    log "  $M_VAULT_PATH"
    log ""
  fi
  printf 'Type "yes" (literally) to proceed, anything else to abort: '
  local answer
  read -r answer || answer=""
  if [ "$answer" != "yes" ]; then
    log "Aborted."
    exit 0
  fi
}

# ---------------------------------------------------------------------------
# Action: strip THINK OS block from a file
# ---------------------------------------------------------------------------
_strip_block() {
  local target="$1"
  if [ ! -f "$target" ]; then
    log "  Skip: $target (not present)"
    return 0
  fi
  if ! grep -q '<!-- BEGIN THINK OS -->' "$target" 2>/dev/null; then
    log "  Skip: $target (no Think OS block present)"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "  Would strip Think OS block from: $target"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk '
    /^<!-- BEGIN THINK OS -->$/ { skip = 1; next }
    /^<!-- END THINK OS -->$/   { skip = 0; next }
    skip != 1 { print }
  ' "$target" > "$tmp"

  mv "$tmp" "$target"
  log "  Stripped Think OS block from: $target"
}

# ---------------------------------------------------------------------------
# Action: remove file (no-op if missing)
# ---------------------------------------------------------------------------
_rm_file() {
  local target="$1"
  if [ ! -e "$target" ]; then
    log "  Skip: $target (not present)"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  Would remove: $target"
    return 0
  fi
  rm -f "$target"
  log "  Removed: $target"
}

# ---------------------------------------------------------------------------
# Action: remove an MCP from claude-code (idempotent)
# ---------------------------------------------------------------------------
_remove_cc_mcp() {
  local name="$1"
  if ! command -v claude >/dev/null 2>&1; then
    log "  Skip: claude CLI not found, can't remove MCP '$name'"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  Would run: claude mcp remove $name --scope user"
    return 0
  fi
  # Check if registered.
  if ! claude mcp list 2>/dev/null | grep -q "$name"; then
    log "  Skip: MCP '$name' is not registered in claude mcp list"
    return 0
  fi
  if claude mcp remove "$name" --scope user >/dev/null 2>&1; then
    log "  Removed Claude Code MCP: $name"
  else
    err "  Failed to remove Claude Code MCP '$name' (may need manual cleanup)"
  fi
}

# ---------------------------------------------------------------------------
# Action: basic-memory project removal
# ---------------------------------------------------------------------------
_remove_bm_project() {
  local proj="$1"
  if ! command -v basic-memory >/dev/null 2>&1; then
    log "  Skip: basic-memory CLI not found, can't remove project '$proj'"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  Would run: basic-memory project remove $proj"
    return 0
  fi
  if ! basic-memory project ls --name "$proj" >/dev/null 2>&1; then
    log "  Skip: Basic Memory project '$proj' is not registered"
    return 0
  fi
  if basic-memory project remove "$proj" >/dev/null 2>&1; then
    log "  Unregistered Basic Memory project: $proj"
  else
    err "  Failed to remove Basic Memory project '$proj'"
  fi
}

# ---------------------------------------------------------------------------
# Action: vault directory removal
# ---------------------------------------------------------------------------
_remove_vault_dir() {
  local path="$1"
  if [ -z "$path" ]; then
    log "  Skip: no vault path known"
    return 0
  fi
  if [ ! -d "$path" ]; then
    log "  Skip: vault directory does not exist: $path"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  Would delete vault directory (and all contents): $path"
    return 0
  fi

  # Last-second sanity guard: never delete a path that ISN'T under $HOME or
  # is obviously a system path.
  case "$path" in
    "$HOME"/*) ;;
    *)
      err "  Refusing to delete vault path outside \$HOME: $path"
      return 1
      ;;
  esac
  if [ "$path" = "$HOME" ] || [ "$path" = "/" ]; then
    err "  Refusing to delete suspicious vault path: $path"
    return 1
  fi

  rm -rf "$path"
  log "  Deleted vault directory: $path"
}

# ---------------------------------------------------------------------------
# Phase: execute the plan
# ---------------------------------------------------------------------------
_execute() {
  hdr "Removing Think OS files"

  # 1. Strip CLAUDE.md block.
  if printf '%s\n' "$M_FILES" | grep -q '/\.claude/CLAUDE\.md '; then
    _strip_block "$HOME/.claude/CLAUDE.md"
  fi

  # 2. Slash commands.
  while IFS= read -r line; do
    case "$line" in
      "$HOME/.claude/commands/"*.md) _rm_file "$line" ;;
    esac
  done < <(printf '%s\n' "$M_FILES")

  # 3+4. MCPs.
  hdr "Removing MCPs"
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    if _is_bm_mcp "$m"; then
      if [ "$REMOVE_BASIC_MEMORY" -eq 1 ]; then
        _remove_cc_mcp "$m"
      else
        log "  Skip Claude Code MCP '$m' (pass --remove-basic-memory)"
      fi
    else
      if [ "$REMOVE_MCPS" -eq 1 ]; then
        _remove_cc_mcp "$m"
      else
        log "  Skip Claude Code MCP '$m' (pass --remove-mcps)"
      fi
    fi
  done < <(printf '%s\n' "$M_CC_MCPS")

  # 5. Basic Memory project + binary.
  if [ "$REMOVE_BASIC_MEMORY" -eq 1 ]; then
    hdr "Removing Basic Memory project registration"
    _remove_bm_project "$M_BM_PROJECT"

    # Offer binary uninstall (prompted, not automatic).
    if [ "$DRY_RUN" -eq 0 ] && command -v basic-memory >/dev/null 2>&1; then
      if [ "$YES" -eq 1 ]; then
        log "  Skipping basic-memory binary uninstall (run 'uv tool uninstall basic-memory' manually if desired)."
      else
        printf '  Also uninstall the basic-memory binary via uv? [y/N] '
        local ans
        read -r ans || ans=""
        case "$ans" in
          [yY]|[yY][eE][sS])
            if command -v uv >/dev/null 2>&1; then
              uv tool uninstall basic-memory && log "  Uninstalled basic-memory binary" || err "  uv tool uninstall failed"
            else
              err "  uv not found; uninstall basic-memory manually."
            fi
            ;;
          *) log "  Leaving basic-memory binary installed." ;;
        esac
      fi
    elif [ "$DRY_RUN" -eq 1 ]; then
      log "  Would prompt to uninstall basic-memory binary via 'uv tool uninstall basic-memory'."
    fi
  fi

  # 6. ~/.thinkos state files.
  hdr "Removing Think OS state files"
  _rm_file "$THINKOS_DIR/vaults.json"
  _rm_file "$THINKOS_DIR/active-vault"
  _rm_file "$THINKOS_DIR/claude-code-bundle.txt"
  _rm_file "$THINKOS_DIR/install-manifest.json"

  # Remove dir if it ends up empty.
  if [ -d "$THINKOS_DIR" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      log "  Would remove $THINKOS_DIR if empty after cleanup."
    else
      # rmdir fails non-fatally if non-empty.
      if rmdir "$THINKOS_DIR" 2>/dev/null; then
        log "  Removed empty directory: $THINKOS_DIR"
      else
        log "  Kept $THINKOS_DIR (still contains user-created files)"
      fi
    fi
  fi

  # 7. Vault directory.
  if [ "$REMOVE_VAULT" -eq 1 ]; then
    hdr "Removing vault directory"
    _remove_vault_dir "$M_VAULT_PATH"
  fi
}

# ---------------------------------------------------------------------------
# Phase: post-uninstall checklist
# ---------------------------------------------------------------------------
_print_post_checklist() {
  hdr "Post-uninstall checklist"

  # Plugin removal instructions (no CLI path).
  local has_plugins=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    has_plugins=1
    break
  done < <(printf '%s\n' "$M_PLUGINS")

  if [ "$has_plugins" -eq 1 ]; then
    log ""
    log "Claude Code plugin removal (no CLI auto-removal available)."
    log "Open Claude Code interactively and run these commands one at a time:"
    log ""
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local slug="${line%%|*}"
      local mp="${line##*|}"
      log "  /plugin remove ${slug}@${mp}"
    done < <(printf '%s\n' "$M_PLUGINS")
    log ""
    log "After that, run '/plugin marketplace remove <mp>' for any marketplaces"
    log "you no longer want."
  fi

  # Time Machine / APFS exclusions (placeholder for Slice 2).
  log ""
  log "Time Machine exclusions: none configured yet (slice 2 will add .private/)."
  log "APFS encrypted vaults: not built yet, nothing to remove."

  # Vault status.
  log ""
  if [ "$REMOVE_VAULT" -eq 1 ]; then
    if [ -n "$M_VAULT_PATH" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        log "Vault data: WOULD BE DELETED at $M_VAULT_PATH (--remove-vault, dry-run)."
      else
        log "Vault data: DELETED. Path was $M_VAULT_PATH"
      fi
    fi
  else
    if [ -n "$M_VAULT_PATH" ]; then
      log "Vault data preserved at: $M_VAULT_PATH"
      log "  (re-run with --remove-vault if you also want to delete the contents)"
    else
      log "Vault data: no vault path known; nothing to preserve."
    fi
  fi

  log ""
  log "Done."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
# --yes is required to actually perform --remove-* (defense in depth).
if [ "$DRY_RUN" -eq 0 ]; then
  if [ "$REMOVE_VAULT" -eq 1 ] && [ "$YES" -eq 0 ] && [ ! -t 0 ]; then
    err "Error: --remove-vault requires --yes when running non-interactively."
    exit 2
  fi
fi

# Resolve the manifest path.
if [ -n "$MANIFEST_OVERRIDE" ]; then
  MANIFEST_PATH="$MANIFEST_OVERRIDE"
else
  MANIFEST_PATH="$DEFAULT_MANIFEST"
fi

if _load_manifest "$MANIFEST_PATH"; then
  log "Loaded install manifest: $MANIFEST_PATH"
else
  if [ -n "$MANIFEST_OVERRIDE" ]; then
    err "Error: manifest at $MANIFEST_OVERRIDE could not be read or is invalid."
    err "Re-run without --manifest to fall back to repo enumeration."
    exit 1
  fi
  log "No install manifest found at $MANIFEST_PATH; falling back to repo enumeration."
  log "(This is normal for installs done before manifest writing was added.)"
  _fallback_enumerate
fi

# Sanity: if there's truly nothing to do, exit cleanly.
if [ -z "$M_PRODUCTS" ] && [ -z "$M_VAULT_PATH" ] \
    && [ -z "$(printf '%s' "$M_FILES$M_CC_MCPS$M_PLUGINS" | tr -d '[:space:]')" ]; then
  log ""
  log "Nothing detected that looks like a Think OS install. Exiting."
  exit 0
fi

_print_plan

# Confirm + execute.
if [ "$DRY_RUN" -eq 1 ]; then
  log "[dry-run] No changes will be made."
else
  _confirm
fi

_execute
_print_post_checklist

exit 0
