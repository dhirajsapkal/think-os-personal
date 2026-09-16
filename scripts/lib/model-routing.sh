#!/usr/bin/env bash
# =============================================================================
# scripts/lib/model-routing.sh — right model for the task
# =============================================================================
# Every scheduled Think OS task spawns `claude -p`. Left unset, each one runs on
# whatever the default model is — which means a keyword-and-timestamp extraction
# job costs the same as a synthesis job that actually needs judgment.
#
# The split that matters is not "hard vs easy". It is:
#
#   EXTRACTION   the answer is already in the input; the job is to find it,
#                shape it, and drop the rest.  → haiku
#   JUDGMENT     the job is to decide something the input does not state —
#                what matters, what is a duplicate, what to propose.  → sonnet
#   DELIBERATION multi-step reasoning where a wrong call is expensive and not
#                obviously wrong.  → opus (nothing scheduled needs this today)
#
# A task that reads a transcript and pulls out "who said they'd do what" is
# extraction. A task that decides which of those commitments matters this week,
# and whether it duplicates an existing ticket, is judgment.
#
# Deterministic tasks (reindex) call no model at all and appear here as "none"
# so the table stays the single place to look.
#
# Override per task with THINKOS_MODEL_<TASK> (dashes become underscores,
# uppercased), or globally with THINKOS_MODEL. Env always wins — this table is
# a default, not a policy.
#
#   THINKOS_MODEL_WEEKLY_REVIEW=opus bash scripts/thinkos-cron-run.sh weekly-review
# =============================================================================

# model_for <task-id> → prints a model alias, or "none" for deterministic tasks.
model_for() {
  local task="$1" key val

  # Per-task env override wins.
  key="THINKOS_MODEL_$(printf '%s' "$task" | tr 'a-z-' 'A-Z_')"
  val="$(eval "printf '%s' \"\${$key:-}\"")"
  [[ -n "$val" ]] && { printf '%s' "$val"; return 0; }

  # Global override.
  [[ -n "${THINKOS_MODEL:-}" ]] && { printf '%s' "$THINKOS_MODEL"; return 0; }

  case "$task" in
    # --- EXTRACTION: the answer is in the input ---------------------------
    # Pull structured items out of connector responses and transcripts, apply
    # a keyword filter, write a note. No call worth making is ambiguous.
    granola|slack|gmail|calendar|clickup)  printf 'haiku' ;;
    morning-brief)                         printf 'haiku' ;;
    quarterly-archive)                     printf 'haiku' ;;

    # --- JUDGMENT: the input does not state the answer --------------------
    # weekly-review decides what mattered and proposes next week's priorities.
    # loose-ends decides whether a spoken commitment is already tracked —
    # semantic matching, where over-reporting erodes trust in the command.
    # figma decides which threads are relevant to the user.
    weekly-review|loose-ends|figma)        printf 'sonnet' ;;
    # checkpoint looks like extraction and is not. A transcript states what was
    # PROPOSED in the same confident past tense as what was DONE; telling them
    # apart is judgment. Measured on the same slice with the same prompt: haiku
    # ignored the required headings and asserted a version bump, a benchmark
    # result and a token count that never happened. sonnet used the headings and
    # every item traced to something real.
    checkpoint)                            printf 'sonnet' ;;

    # --- DETERMINISTIC ----------------------------------------------------
    daily-reindex)                         printf 'none' ;;

    *)                                     printf 'sonnet' ;;
  esac
}

# model_flag <task-id> → "--model haiku", or empty for deterministic/unset.
# Use as: claude -p $(model_flag "$TASK_ID") "$prompt"
model_flag() {
  local m; m="$(model_for "$1")"
  [[ "$m" == "none" || -z "$m" ]] && return 0
  printf -- '--model %s' "$m"
}

# Direct invocation, so the table is inspectable:
#   bash scripts/lib/model-routing.sh            list every task
#   bash scripts/lib/model-routing.sh <task>     one task
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ -n "${1:-}" ]]; then
    model_for "$1"; echo
  else
    printf '%-18s %s\n' "TASK" "MODEL"
    for t in granola slack gmail calendar clickup checkpoint morning-brief \
             quarterly-archive weekly-review loose-ends figma daily-reindex; do
      printf '%-18s %s\n' "$t" "$(model_for "$t")"
    done
  fi
fi
