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
  --products LIST    Comma-separated subset to update (claude-code,all).
                     Default: auto-detect installed.
  --dry-run          Show what would change without writing.
  -h, --help         Show this help

What gets re-applied:
  - The BEGIN/END THINK OS block in:
      ~/.claude/CLAUDE.md             (Claude Code)
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
    "$dir/30-think-os-write-targets.md" \
    "$dir/40-emergent-seeding.md" \
    "$dir/50-drift-detection.md" \
    "$dir/60-shared-mode.md" \
    "$dir/70-claude-ai-bridge.md"
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

# Cowork/Codex adapters cut in v0.7.0 — see roadmap/cowork-codex branch.

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
  PRODUCTS="claude-code"
fi

UPDATED_COUNT=0

if has_product "claude-code"; then
  update_claude_code
  UPDATED_COUNT=$((UPDATED_COUNT + 1))
fi

log
log "Updated: $UPDATED_COUNT product(s)."

# ---------------------------------------------------------------------------
# Refresh the install-manifest baselines.
#
# Without this, shipped_sha values accumulate "lag" — they were set at install
# (or migration) time and never refreshed by subsequent --skip-pull runs.
# Result: false-positive drift on files the user never manually edited.
#
# Runs only when:
#   - The install-manifest is v2+ (has managed_files array)
#   - We're not in --dry-run mode
#   - The repo is a git checkout (so we can read HEAD)
# ---------------------------------------------------------------------------
MANIFEST="$HOME/.thinkos/install-manifest.json"
if [[ "$DRY_RUN" -eq 0 ]] && [[ -f "$MANIFEST" ]] && [[ -d "$REPO_ROOT/.git" ]]; then
  HEAD_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "")"
  if [[ -n "$HEAD_SHA" ]]; then
    python3 - "$MANIFEST" "$HEAD_SHA" 2>/dev/null <<'PY' || log "Note: manifest baseline refresh skipped (manifest may be v1)."
import json, sys, hashlib, os, re
from datetime import datetime, timezone

manifest_path, new_version = sys.argv[1], sys.argv[2]
BEGIN = "<!-- BEGIN THINK OS -->"
END   = "<!-- END THINK OS -->"

m = json.load(open(manifest_path))
files = m.get("managed_files")
if not files:
    sys.exit(0)  # v1 manifest — nothing to refresh

updated = 0
for f in files:
    target = f.get("target")
    mode = f.get("mode", "file")
    if not target or not os.path.exists(target):
        continue
    if mode == "block":
        text = open(target).read()
        match = re.search(re.escape(BEGIN) + r"(.*?)" + re.escape(END), text, re.DOTALL)
        h = hashlib.sha256(match.group(1).encode("utf-8")).hexdigest() if match else None
    else:
        h = hashlib.sha256(open(target, "rb").read()).hexdigest()
    if h:
        f["shipped_sha"] = h
        f["current_sha"] = h
        updated += 1

m["thinkos_version"] = new_version
m["last_updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# Atomic write
tmp = manifest_path + ".tmp"
with open(tmp, "w") as fp:
    json.dump(m, fp, indent=2)
    fp.write("\n")
os.rename(tmp, manifest_path)

print(f"[manifest] thinkos_version → {new_version[:10]}, shipped_sha refreshed for {updated} files")
PY
  fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "(Dry run — no files were modified.)"
fi
