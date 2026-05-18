#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-git.sh — Lazy git install/auth helper for project vaults
# =============================================================================
# Invoked by `thinkos-vault.sh` only when a project-vault git op is requested.
# Personal-hub-only users never trigger this script.
#
# Subcommands:
#   check-or-install   Verify `git` on PATH and user.name/user.email set
#   check-auth         Check GitHub auth (gh preferred, ssh fallback)
#   setup-ssh          Interactive ed25519 keygen + GitHub paste walkthrough
#   setup-gh           Install + auth `gh` CLI (brew + gh auth login)
#   sync-vault         Commit local changes, pull --rebase, push
#   -h, --help
#
# Flags (where applicable):
#   --yes              Non-interactive; fail rather than prompt
#
# sync-vault flags:
#   --vault <path>     Vault to sync (default: active personal hub)
#   --message <msg>    Commit message (default: auto-generated)
#   --dry-run          Preview planned actions without executing
#
# Exit codes:
#   0 — all good
#   1 — something missing the user must fix; instructions printed
#   2 — usage error
# =============================================================================
set -uo pipefail

YES=0

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-git.sh <subcommand> [flags]

Subcommands:
  check-or-install   Verify git is installed and user.name/user.email are set.
                     Prompts to set them if missing (unless --yes, then fails).
  check-auth         Check GitHub authentication. Prefers `gh auth status`;
                     falls back to `ssh -T git@github.com`. Prints
                     remediation instructions on failure.
  setup-ssh          Walk through ed25519 keygen, copy public key, open
                     GitHub's "Add SSH key" page, verify with ssh -T.
  setup-gh           Install gh via brew (if missing), then `gh auth login`.
  sync-vault         Commit local vault changes, pull --rebase from remote,
                     then push. Pauses on conflict — never auto-resolves.
  -h, --help         Show this help.

Global flags:
  --yes              Non-interactive; fail rather than prompt.

sync-vault flags:
  --vault <path>     Path to the vault git repo (default: active personal hub
                     resolved from ~/.thinkos/active-vault or vaults.json).
  --message <msg>    Commit message for local changes (default: auto-generated
                     "chore(vault): sync YYYY-MM-DD HH:MM").
  --dry-run          Print planned actions without executing any git commands.

Examples:
  scripts/thinkos-git.sh check-or-install
  scripts/thinkos-git.sh check-auth
  scripts/thinkos-git.sh setup-ssh
  scripts/thinkos-git.sh sync-vault
  scripts/thinkos-git.sh sync-vault --vault ~/ThinkOS/vault --dry-run
  scripts/thinkos-git.sh sync-vault --message "save progress before travel"
EOF
}

log() { printf '%s\n' "$*"; }
err() { printf '%s\n' "$*" >&2; }

# -----------------------------------------------------------------------------
# check-or-install — git present, user.name and user.email set
# -----------------------------------------------------------------------------
cmd_check_or_install() {
  if ! command -v git >/dev/null 2>&1; then
    err "git is not installed."
    err ""
    err "Install it with Homebrew:"
    err "  brew install git"
    err ""
    err "Or install the Apple Developer Command Line Tools:"
    err "  xcode-select --install"
    return 1
  fi
  log "git found: $(command -v git) ($(git --version 2>/dev/null))"

  local name email
  name="$(git config --global user.name 2>/dev/null || true)"
  email="$(git config --global user.email 2>/dev/null || true)"

  if [ -n "$name" ] && [ -n "$email" ]; then
    log "git identity: $name <$email>"
    return 0
  fi

  if [ "$YES" -eq 1 ]; then
    err "git user.name and/or user.email are not set."
    err ""
    err "Run interactively, or set them manually:"
    err "  git config --global user.name \"Your Name\""
    err "  git config --global user.email \"you@example.com\""
    return 1
  fi

  log ""
  log "git needs your name and email for commit authorship."
  if [ -z "$name" ]; then
    local in_name
    printf '  Enter your name: '
    read -r in_name || in_name=""
    if [ -z "$in_name" ]; then
      err "No name entered. Aborting."
      return 1
    fi
    git config --global user.name "$in_name"
    log "  set: user.name = $in_name"
  fi
  if [ -z "$email" ]; then
    local in_email
    printf '  Enter your email: '
    read -r in_email || in_email=""
    if [ -z "$in_email" ]; then
      err "No email entered. Aborting."
      return 1
    fi
    git config --global user.email "$in_email"
    log "  set: user.email = $in_email"
  fi

  return 0
}

# -----------------------------------------------------------------------------
# check-auth — confirm GitHub auth works
# -----------------------------------------------------------------------------
cmd_check_auth() {
  # Prefer gh if available.
  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
      log "GitHub auth: gh CLI is authenticated."
      return 0
    fi
    log "gh is installed but not authenticated."
  fi

  # SSH fallback. `ssh -T git@github.com` returns 1 on success (GitHub never
  # opens a shell), so we detect the "successfully authenticated" string.
  if command -v ssh >/dev/null 2>&1; then
    local ssh_out
    ssh_out="$(ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes -T git@github.com 2>&1 || true)"
    case "$ssh_out" in
      *"successfully authenticated"*)
        log "GitHub auth: SSH key works."
        return 0
        ;;
    esac
  fi

  err "GitHub authentication is not set up."
  err ""
  err "Pick one of these and run it, then re-try your vault command:"
  err ""
  err "  Option A — SSH (recommended for git push/pull):"
  err "    scripts/thinkos-git.sh setup-ssh"
  err ""
  err "  Option B — GitHub CLI (also gives you HTTPS auth + gh commands):"
  err "    scripts/thinkos-git.sh setup-gh"
  return 1
}

# -----------------------------------------------------------------------------
# setup-ssh — ed25519 keygen + GitHub paste
# -----------------------------------------------------------------------------
cmd_setup_ssh() {
  if [ "$YES" -eq 1 ]; then
    err "setup-ssh is interactive; cannot run with --yes."
    return 2
  fi

  local key="$HOME/.ssh/id_ed25519"
  local pub="$key.pub"

  if [ -f "$pub" ]; then
    log "Found existing public key at: $pub"
  else
    log "No ed25519 key found. Generating one."
    local email
    email="$(git config --global user.email 2>/dev/null || true)"
    if [ -z "$email" ]; then
      printf '  Enter the email to label the key with: '
      read -r email || email=""
      [ -z "$email" ] && email="thinkos@$(hostname)"
    fi
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    # No passphrase prompt loop here — ssh-keygen handles it interactively.
    ssh-keygen -t ed25519 -C "$email" -f "$key" || {
      err "ssh-keygen failed."
      return 1
    }
  fi

  log ""
  log "Your public key (copied to clipboard if pbcopy is available):"
  log "----------------------------------------------------------------"
  cat "$pub"
  log "----------------------------------------------------------------"
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$pub"
    log "(public key copied to clipboard)"
  fi

  log ""
  log "Next:"
  log "  1. The GitHub 'Add new SSH key' page will open in your browser."
  log "  2. Paste the public key above (already on clipboard)."
  log "  3. Give it a title (e.g. '$(hostname)') and click 'Add SSH key'."
  log ""
  if command -v open >/dev/null 2>&1; then
    open "https://github.com/settings/ssh/new" >/dev/null 2>&1 || true
  else
    log "  Open this URL manually: https://github.com/settings/ssh/new"
  fi

  local _unused
  printf '\n  Press ENTER once you have pasted the key in GitHub... '
  read -r _unused || true

  log ""
  log "Verifying with: ssh -T git@github.com"
  local ssh_out
  ssh_out="$(ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
  case "$ssh_out" in
    *"successfully authenticated"*)
      log "SSH auth verified."
      return 0
      ;;
    *)
      err "SSH check did not succeed. Output was:"
      err "$ssh_out"
      err ""
      err "Re-run this command after confirming the key is on your GitHub account:"
      err "  scripts/thinkos-git.sh setup-ssh"
      return 1
      ;;
  esac
}

# -----------------------------------------------------------------------------
# setup-gh — install gh + auth login
# -----------------------------------------------------------------------------
cmd_setup_gh() {
  if [ "$YES" -eq 1 ]; then
    err "setup-gh is interactive; cannot run with --yes."
    return 2
  fi

  if ! command -v gh >/dev/null 2>&1; then
    if ! command -v brew >/dev/null 2>&1; then
      err "Homebrew is required to install gh, and it's not on PATH."
      err "Install Homebrew first: https://brew.sh"
      return 1
    fi
    log "Installing gh via Homebrew..."
    brew install gh || {
      err "brew install gh failed."
      return 1
    }
  else
    log "gh already installed: $(command -v gh)"
  fi

  log ""
  log "Starting GitHub auth flow (gh auth login)."
  log "Choose: GitHub.com → HTTPS or SSH → Login with a web browser."
  log ""
  gh auth login || {
    err "gh auth login did not complete."
    return 1
  }

  log ""
  log "Verifying with: gh auth status"
  gh auth status || {
    err "gh auth status reports not authenticated."
    return 1
  }
  log "GitHub auth via gh verified."
}

# -----------------------------------------------------------------------------
# sync-vault — commit, pull --rebase, push; never auto-resolve conflicts
# -----------------------------------------------------------------------------
cmd_sync_vault() {
  local vault_path="" commit_msg="" dry_run=0

  # Parse sync-vault-specific flags from remaining args
  while [ $# -gt 0 ]; do
    case "$1" in
      --vault)
        [ $# -lt 2 ] && { err "--vault requires a path argument"; return 2; }
        vault_path="$2"; shift 2 ;;
      --message)
        [ $# -lt 2 ] && { err "--message requires a value"; return 2; }
        commit_msg="$2"; shift 2 ;;
      --dry-run)
        dry_run=1; shift ;;
      --yes)
        YES=1; shift ;;
      -h|--help)
        usage; return 0 ;;
      *)
        err "Unknown flag for sync-vault: $1"
        usage >&2
        return 2 ;;
    esac
  done

  # ── Vault resolution ─────────────────────────────────────────────────────
  # 1. Explicit --vault flag
  # 2. Sticky override: ~/.thinkos/active-vault
  # 3. vaults.json default:true entry
  # 4. Fall back to THINKOS_VAULT env if set
  if [ -z "$vault_path" ]; then
    if [ -n "${THINKOS_VAULT:-}" ]; then
      vault_path="$THINKOS_VAULT"
    elif [ -f "$HOME/.thinkos/active-vault" ]; then
      vault_path="$(cat "$HOME/.thinkos/active-vault" | tr -d '[:space:]')"
    elif [ -f "$HOME/.thinkos/vaults.json" ]; then
      vault_path="$(python3 -c "
import json, sys
vaults = json.load(open('$HOME/.thinkos/vaults.json'))
entries = vaults if isinstance(vaults, list) else vaults.get('vaults', [])
for v in entries:
    if v.get('default') or v.get('type') == 'personal':
        print(v.get('path', ''))
        break
" 2>/dev/null || true)"
    fi
  fi

  if [ -z "$vault_path" ]; then
    err "Could not resolve vault path. Provide --vault <path> or set up ~/.thinkos/vaults.json."
    return 1
  fi

  vault_path="${vault_path/#\~/$HOME}"

  if [ ! -d "$vault_path/.git" ]; then
    err "Not a git repository: $vault_path"
    err "Initialize with: git -C \"$vault_path\" init"
    return 1
  fi

  # ── Auto-generate commit message ─────────────────────────────────────────
  if [ -z "$commit_msg" ]; then
    commit_msg="chore(vault): sync $(date '+%Y-%m-%d %H:%M')"
  fi

  # ── Step 1: Check if vault is already up to date ─────────────────────────
  local porcelain_out
  porcelain_out="$(git -C "$vault_path" status --porcelain 2>/dev/null)"

  # Check for incoming commits (requires network; skip on failure)
  local incoming_count=0
  if [ "$dry_run" -eq 0 ]; then
    git -C "$vault_path" fetch --quiet 2>/dev/null || true
    incoming_count="$(git -C "$vault_path" rev-list HEAD..origin/HEAD --count 2>/dev/null || echo 0)"
  fi

  if [ -z "$porcelain_out" ] && [ "$incoming_count" -eq 0 ] && [ "$dry_run" -eq 0 ]; then
    log "Vault is up to date."
    return 0
  fi

  # ── Step 2: Stage and commit local changes ────────────────────────────────
  if [ -n "$porcelain_out" ]; then
    if [ "$dry_run" -eq 1 ]; then
      log "[dry-run] Would stage all changes in: $vault_path"
      log "[dry-run] Would commit with message: $commit_msg"
      log "[dry-run] Changed files:"
      printf '%s\n' "$porcelain_out" | sed 's/^/  /'
    else
      log "Staging changes..."
      if git -C "$vault_path" ls-files --others --exclude-standard | grep -qE '^(\.claude/|\.ssh/|\.gnupg/|\.aws/|\.docker/)'; then
        err "WARNING: sync would stage files matching sensitive paths. Aborting."
        err "Inspect with: git -C \"$vault_path\" status"
        return 1
      fi
      git -C "$vault_path" add -A
      log "Committing: $commit_msg"
      git -C "$vault_path" commit -m "$commit_msg"
    fi
  else
    [ "$dry_run" -eq 1 ] && log "[dry-run] No local changes to commit."
  fi

  # ── Step 3: Pull with rebase ──────────────────────────────────────────────
  if [ "$dry_run" -eq 1 ]; then
    log "[dry-run] Would run: git -C \"$vault_path\" pull --rebase"
    log "[dry-run] On conflict: would print conflicted files and exit 1 (never auto-resolve)."
    log "[dry-run] Would run: git -C \"$vault_path\" push"
    return 0
  fi

  log "Pulling (rebase)..."
  local pull_exit=0
  git -C "$vault_path" pull --rebase 2>&1 || pull_exit=$?

  if [ "$pull_exit" -ne 0 ]; then
    local conflict_files
    conflict_files="$(git -C "$vault_path" diff --name-only --diff-filter=U 2>/dev/null || true)"
    err ""
    err "── Sync conflict ──────────────────────────────────────────────────"
    err "git pull --rebase exited with status $pull_exit."
    if [ -n "$conflict_files" ]; then
      err "Conflicted files:"
      printf '%s\n' "$conflict_files" | sed 's/^/  /' >&2
    fi
    err ""
    err "Status:"
    git -C "$vault_path" status 2>&1 | sed 's/^/  /' >&2
    err ""
    err "Recovery options:"
    err "  A. Edit the conflicted files, resolve markers, then run /thinkos-sync again."
    err "  B. Abort the rebase: git -C \"$vault_path\" rebase --abort"
    err ""
    err "Think OS never auto-resolves conflicts. A human decision is required."
    return 1
  fi

  # ── Step 4: Push ─────────────────────────────────────────────────────────
  log "Pushing..."
  local push_exit=0
  git -C "$vault_path" push 2>&1 || push_exit=$?

  if [ "$push_exit" -ne 0 ]; then
    err ""
    err "── Push rejected ──────────────────────────────────────────────────"
    err "git push exited with status $push_exit."
    err "The remote has diverged in a way that rebase did not resolve."
    err ""
    err "Recovery options:"
    err "  A. Investigate: git -C \"$vault_path\" log --oneline origin/HEAD..HEAD"
    err "  B. Run /thinkos-sync again after confirming the remote state."
    err ""
    err "Never force-push without explicitly reviewing what would be overwritten."
    return 1
  fi

  log "Vault synced successfully."
  return 0
}

# -----------------------------------------------------------------------------
# Arg parsing
# -----------------------------------------------------------------------------
if [ $# -eq 0 ]; then
  usage
  exit 0
fi

SUB=""
# Consume the first non-flag arg as the subcommand; pass remaining args to the
# subcommand function so each can parse its own flags.
REMAINING_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --yes)
      YES=1
      REMAINING_ARGS+=("$arg")
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ -z "$SUB" ]; then
        SUB="$arg"
      else
        REMAINING_ARGS+=("$arg")
      fi
      ;;
  esac
done

case "$SUB" in
  check-or-install) cmd_check_or_install ;;
  check-auth)       cmd_check_auth ;;
  setup-ssh)        cmd_setup_ssh ;;
  setup-gh)         cmd_setup_gh ;;
  sync-vault)       cmd_sync_vault "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}" ;;
  "")
    usage
    exit 0
    ;;
  *)
    err "Unknown subcommand: $SUB"
    usage >&2
    exit 2
    ;;
esac
