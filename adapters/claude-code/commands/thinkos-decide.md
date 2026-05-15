---
description: Record a standing decision in your vault (alias for /thinkos-capture --mode decision)
permalink: think-os/adapters/claude-code/commands/thinkos-decide
---

**This command now delegates to `/thinkos-capture` with `--mode decision`. Result is identical; one fewer command to remember.**

Follow `adapters/claude-code/commands/thinkos-capture.md` with `$ARGUMENTS` treated as if the user had typed `/thinkos-capture --mode decision $ARGUMENTS`. The canonical playbook handles formatting, ledger event, and confirmation.

Show this one-line hint to the user exactly once per session (track via the session-scoped reasoning; do not re-surface on every invocation):

> Routing through /thinkos-capture (same behavior, one fewer command to remember).

User message: $ARGUMENTS
