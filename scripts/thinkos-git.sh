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
#   -h, --help
#
# Flags (where applicable):
#   --yes              Non-interactive; fail rather than prompt
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
Usage: scripts/thinkos-git.sh <subcommand> [--yes]

Subcommands:
  check-or-install   Verify git is installed and user.name/user.email are set.
                     Prompts to set them if missing (unless --yes, then fails).
  check-auth         Check GitHub authentication. Prefers `gh auth status`;
                     falls back to `ssh -T git@github.com`. Prints
                     remediation instructions on failure.
  setup-ssh          Walk through ed25519 keygen, copy public key, open
                     GitHub's "Add SSH key" page, verify with ssh -T.
  setup-gh           Install gh via brew (if missing), then `gh auth login`.
  -h, --help         Show this help.

Examples:
  scripts/thinkos-git.sh check-or-install
  scripts/thinkos-git.sh check-auth
  scripts/thinkos-git.sh setup-ssh
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
# Arg parsing
# -----------------------------------------------------------------------------
if [ $# -eq 0 ]; then
  usage
  exit 0
fi

SUB=""
for arg in "$@"; do
  case "$arg" in
    --yes) YES=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      err "Unknown flag: $arg"
      usage >&2
      exit 2
      ;;
    *)
      if [ -z "$SUB" ]; then
        SUB="$arg"
      else
        err "Unexpected argument: $arg"
        usage >&2
        exit 2
      fi
      ;;
  esac
done

case "$SUB" in
  check-or-install) cmd_check_or_install ;;
  check-auth)       cmd_check_auth ;;
  setup-ssh)        cmd_setup_ssh ;;
  setup-gh)         cmd_setup_gh ;;
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
