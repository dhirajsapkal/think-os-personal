#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-continue.sh — Resume Think OS onboarding from any state
# =============================================================================
# Reads the wizard state file and tells the user (or agent) exactly where they
# are and what to do next. This is the human-facing entry point for Phase 2;
# the agent equivalent lives in:
#   adapters/claude-code/commands/thinkos-continue.md
#
# This script does no mutation. It prints next-step instructions and points
# at the playbook the agent should follow.
# (Cowork/Codex adapters cut in v0.7.0 — see roadmap/cowork-codex branch.)
#
# Usage:
#   scripts/thinkos-continue.sh
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="$HOME/.thinkos/wizard-state.json"

printf '\n══════════════════════════════════════════════════════════════════════\n'
printf '  THINK OS — CONTINUE SETUP\n'
printf '══════════════════════════════════════════════════════════════════════\n\n'

if [[ ! -f "$STATE_FILE" ]]; then
  cat <<EOF
  No setup state found. It looks like Phase 1 hasn't run yet (or the
  state file at $STATE_FILE was removed).

  Run Phase 1 first — easiest path:

      In Claude Code, paste:
        Install Think OS for me from https://github.com/dhirajsapkal/think-os

  Or the script directly:

      bash $SCRIPT_DIR/thinkos-setup.sh --os-home ~/ThinkOS/vault --yes

EOF
  exit 1
fi

# Pretty-print where the user is.
bash "$SCRIPT_DIR/thinkos-state.sh" where-am-i
printf '\n'

# Phase-specific guidance.
phase="$(bash "$SCRIPT_DIR/thinkos-state.sh" get phase)"

case "$phase" in
  awaiting_oauth_and_restart)
    cat <<EOF
══════════════════════════════════════════════════════════════════════
  WHAT TO DO NEXT
══════════════════════════════════════════════════════════════════════

  Phase 1 finished, but a few steps cannot be automated:

    1. Complete OAuth in each app that asks for it. In Claude Code:
       run 'claude', type '/mcp', authorize each connector.

    2. Restart your agent apps so MCPs and plugins load fresh.

  Once those are done, run this script again. The phase will advance to
  'ready_for_seeding' and you can begin Phase 2 (content seeding).

  To manually mark Phase 1 fully done after restart:
      bash $SCRIPT_DIR/thinkos-state.sh set-phase ready_for_seeding

EOF
    ;;

  ready_for_seeding)
    cat <<EOF
══════════════════════════════════════════════════════════════════════
  PHASE 2 — CONTEXT SEEDING
══════════════════════════════════════════════════════════════════════

  You're ready. Phase 2 reads from your connected tools and drafts the
  HOT-tier files (Identity, Current Focus, Project Index, People). Every
  draft is shown to you for review before it's written to your vault.

  Phase 2 is agent-driven. Open Claude Code and run the
  /thinkos-continue slash command (or just say "continue Think OS setup"):

    · In Claude Code:    open the export repo, type /thinkos-continue

  The agent will follow:
      $REPO_ROOT/docs/phase-2-seeding-playbook.md

  Privacy notes:
    · The agent asks for explicit consent before reading each connector.
    · Drafts are shown with citations; nothing writes to your vault
      without your approval.
    · You can skip any source, any file, or the whole phase.

EOF
    ;;

  seeding)
    cat <<EOF
══════════════════════════════════════════════════════════════════════
  PHASE 2 IN PROGRESS
══════════════════════════════════════════════════════════════════════

  Resume by invoking /thinkos-continue in your agentic tool again. The
  agent reads the state file and picks up where it left off.

  To see which files have been seeded:
      bash $SCRIPT_DIR/thinkos-state.sh get files_seeded

EOF
    ;;

  complete)
    cat <<EOF
══════════════════════════════════════════════════════════════════════
  SETUP COMPLETE
══════════════════════════════════════════════════════════════════════

  Nothing to do — Think OS is fully set up and seeded.

  To re-seed a specific file (e.g. after a job change or project shift):
      bash $SCRIPT_DIR/thinkos-state.sh set files_seeded.<file> false
      bash $SCRIPT_DIR/thinkos-state.sh set-phase seeding
      # then run /thinkos-continue in your agent

  To see your vault status anytime:
      bash $SCRIPT_DIR/thinkos-doctor.sh --deep

EOF
    ;;

  *)
    printf '  Unknown phase: %s. Inspect the state file:\n' "$phase"
    printf '      cat %s\n\n' "$STATE_FILE"
    exit 1
    ;;
esac

exit 0
