#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Error: Think OS scripts must not be run as root. Run as your normal user." >&2
  exit 1
fi

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
  --products LIST             Comma-separated products: claude-code,all
  --install-basic-memory      Install Basic Memory with uv if missing
  --skip-mcp                  Do not register MCPs in product CLIs
  --yes                       Non-interactive mode; accept safe defaults
  --dry-run                   Show what would happen without changing files
  --bundle PRESET             Install a curated bundle after product setup (pm|eng|design|ops|all)
  --bundle-items LIST         Comma-separated catalog ids to install (advanced)
  -h, --help                  Show this help

Examples:
  scripts/thinkos-setup.sh --products claude-code --install-basic-memory --yes
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
  PRODUCTS="claude-code"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/templates"

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/render-instructions.sh"

if [[ -z "$PRODUCTS" && -t 0 && "$YES" -eq 0 ]]; then
  read -r -p "Products to set up [claude-code]: " PRODUCTS
  PRODUCTS="${PRODUCTS:-claude-code}"
fi

if [[ -z "$PRODUCTS" ]]; then
  PRODUCTS="claude-code"
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
  #   instructions/  — curated agent-instruction stack (rendered into the
  #                    BEGIN/END THINK OS block, never copied into a vault)
  #   team/          — project-vault template skeleton (copied by
  #                    thinkos-vault.sh create-project, never into personal hubs)
  #   LaunchAgents/  — macOS launchd plist templates with __TOKEN__ placeholders.
  #                    Processed by scripts/install-launchd-job.sh,
  #                    install-session-capture.sh, and install-sync-job.sh —
  #                    these read the templates from the repo and write resolved
  #                    plists into ~/Library/LaunchAgents/. Never copied into
  #                    a vault. (Fixed in v0.8.1 after a user's Claude session
  #                    saw the unresolved templates in the vault and concluded
  #                    the install was incomplete.)
  while IFS= read -r -d '' dir; do
    local rel="${dir#./}"
    [[ "$rel" == "." ]] && continue
    [[ "$rel" == "instructions" || "$rel" == instructions/* ]] && continue
    [[ "$rel" == "team" || "$rel" == team/* ]] && continue
    [[ "$rel" == "LaunchAgents" || "$rel" == LaunchAgents/* ]] && continue
    run mkdir -p "$OS_HOME/$rel"
  done < <(cd "$TEMPLATE_DIR" && find . -type d -print0)

  local created_verb="Created"
  [[ "$DRY_RUN" -eq 1 ]] && created_verb="Would create"

  while IFS= read -r -d '' file; do
    local rel="${file#./}"
    [[ "$rel" == instructions/* ]] && continue
    [[ "$rel" == team/* ]] && continue
    [[ "$rel" == LaunchAgents/* ]] && continue
    local dest="$OS_HOME/$rel"
    if [[ -f "$dest" ]]; then
      log "Skip existing: $rel"
    else
      run mkdir -p "$(dirname "$dest")"
      run cp "$TEMPLATE_DIR/$rel" "$dest"
      log "$created_verb: $rel"
    fi
  done < <(cd "$TEMPLATE_DIR" && find . -type f -print0)

  # WP-04: copy .gitignore to vault root (excluded from the find loop above
  # because dotfiles may be skipped by find on some systems; copy explicitly).
  if [[ -f "$TEMPLATE_DIR/.gitignore" && ! -f "$OS_HOME/.gitignore" ]]; then
    run cp "$TEMPLATE_DIR/.gitignore" "$OS_HOME/.gitignore"
    log "$created_verb: .gitignore"
  fi

  # WP-33: ensure Capture Log.md exists (may not have been picked up above if
  # the 90 System dir was newly created and the file was just written).
  local capture_log_dest="$OS_HOME/90 System/Capture Log.md"
  if [[ ! -f "$capture_log_dest" && -f "$TEMPLATE_DIR/90 System/Capture Log.md" ]]; then
    run mkdir -p "$OS_HOME/90 System"
    run cp "$TEMPLATE_DIR/90 System/Capture Log.md" "$capture_log_dest"
    log "$created_verb: 90 System/Capture Log.md"
  fi

  # WP-34: apply Python-based token substitution across all vault template
  # files.  Tokens: {{OS_HOME}}, {{YYYY-MM-DD}}, {{YYYY-MM-DD HH:MM}}.
  # We only touch files that were just installed (exist in the vault); we do
  # NOT re-substitute existing user-owned files to avoid destroying user edits.
  if [[ "$DRY_RUN" -ne 1 ]]; then
    OS_HOME="$OS_HOME" python3 - <<'PYEOF'
import os, datetime

vault = os.environ["OS_HOME"]
now = datetime.datetime.now()
install_date = now.strftime("%Y-%m-%d")
install_datetime = now.strftime("%Y-%m-%d %H:%M")
os_home = vault

tokens = {
    "{{OS_HOME}}": os_home,
    "{{YYYY-MM-DD}}": install_date,
    "{{YYYY-MM-DD HH:MM}}": install_datetime,
}

for root, dirs, files in os.walk(vault):
    # Skip hidden dirs (e.g. .git)
    dirs[:] = [d for d in dirs if not d.startswith(".")]
    for fname in files:
        if not fname.endswith(".md"):
            continue
        fpath = os.path.join(root, fname)
        try:
            with open(fpath, "r", encoding="utf-8") as fh:
                text = fh.read()
        except (UnicodeDecodeError, OSError):
            continue
        new_text = text
        for tok, val in tokens.items():
            new_text = new_text.replace(tok, val)
        if new_text != text:
            with open(fpath, "w", encoding="utf-8") as fh:
                fh.write(new_text)
PYEOF
  fi
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
      if claude mcp list 2>/dev/null | grep -q "^basic-memory:"; then
        log "Claude Code MCP already includes basic-memory"
      else
        run claude mcp add basic-memory --scope user -- basic-memory mcp --project "$PROJECT_NAME"
      fi
    else
      log "Claude Code CLI not found; installed instructions/commands, but skipped MCP registration"
    fi
  fi
}

# Cowork/Codex adapters cut in v0.7.0 — see roadmap/cowork-codex branch.

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
    os.chmod(manifest_path, 0o600)
except Exception:
    try: os.unlink(tmp)
    except OSError: pass
    raise

print("Wrote install manifest: " + manifest_path)
PYEOF

  # Upgrade the just-written v1 manifest to v2 so consumers added after the
  # update-protocol landed (/thinkos-autosave, /thinkos-update, /thinkos-capture-setup)
  # can resolve `repo_path` and `managed_files` on a fresh install. The migrator
  # is idempotent and exits 0 on already-v2 manifests.
  if [[ -x "$REPO_ROOT/scripts/thinkos-migrate-manifest-v1-to-v2.sh" ]]; then
    "$REPO_ROOT/scripts/thinkos-migrate-manifest-v1-to-v2.sh" || \
      log "Warning: manifest v1→v2 migration failed; /thinkos-autosave and /thinkos-update may not work until you run scripts/thinkos-migrate-manifest-v1-to-v2.sh manually."
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
if ! ensure_basic_memory; then
  log "Aborting: Basic Memory setup failed."
  exit 1
fi
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

_write_install_manifest

log
log "Setup steps complete. Run this next:"
log "  $REPO_ROOT/scripts/thinkos-doctor.sh --deep --os-home \"$OS_HOME\" --products \"$PRODUCTS\""

