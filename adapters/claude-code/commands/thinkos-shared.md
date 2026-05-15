---
description: Toggle shared-mode (hide tier:sensitive notes from agent reads)
permalink: think-os/adapters/claude-code/commands/thinkos-shared
---

You are running `/thinkos-shared`. The user wants to toggle **shared-mode** — a session-wide flag that hides `tier: sensitive` notes from agent reads while leaving writes unaffected. Useful when screen-sharing, handing the session to a collaborator, or recording.

## Args

`$ARGUMENTS` is one of:

- `on` — enable shared-mode (write the flag file)
- `off` — disable shared-mode (remove the flag file)
- empty — report current status

## Implementation

```bash
FLAG="$HOME/.thinkos/shared-mode"
mkdir -p "$HOME/.thinkos"

case "$ARGUMENTS" in
  on)
    NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'on since %s\n' "$NOW" > "$FLAG"
    echo "Shared-mode: ON. tier:sensitive notes are now hidden from reads."
    ;;
  off)
    rm -f "$FLAG"
    echo "Shared-mode: OFF. All notes accessible."
    ;;
  "")
    if [ -n "${THINKOS_SHARED:-}" ] && [ "$THINKOS_SHARED" = "1" ]; then
      echo "Shared-mode: ON (via THINKOS_SHARED env var; overrides flag file)."
    elif [ -f "$FLAG" ]; then
      echo "Shared-mode: ON ($(cat "$FLAG"))."
    else
      echo "Shared-mode: OFF."
    fi
    ;;
  *)
    echo "Usage: /thinkos-shared on|off|(empty for status)"
    ;;
esac
```

Run the script, then report the resulting state to the user in one line. Don't echo the command output verbatim — give the user the human summary.

## Effect

When shared-mode is on, the agent (this session and future sessions until toggled off) follows the read-masking rules in the curated instruction block `templates/instructions/60-shared-mode.md`:

- `mcp__basic-memory__search_notes` drops `tier: sensitive` results.
- `mcp__basic-memory__read_note` on a sensitive note returns a redaction message.
- Writes are unaffected — the user can still capture sensitive context mid-shared-session without leaking it.

Drift nudges (`50-drift-detection.md`) are also silent under shared-mode. Re-enable normal behavior with `/thinkos-shared off`.

## Precedence

`THINKOS_SHARED=1` env var (highest) > `~/.thinkos/shared-mode` flag file > off. If the env var is set, this command can write or remove the file but the agent will still treat the session as shared until the env var is unset.

User message: $ARGUMENTS
