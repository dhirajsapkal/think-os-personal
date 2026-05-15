---
description: Capture a timestamped note to your work log (alias for /thinkos-capture --mode log)
permalink: think-os/adapters/claude-code/commands/thinkos-log
---

**This command now delegates to `/thinkos-capture` with `--mode log`. Result is identical; one fewer command to remember.**

Follow `adapters/claude-code/commands/thinkos-capture.md` with `$ARGUMENTS` treated as if the user had typed `/thinkos-capture --mode log $ARGUMENTS`. The canonical playbook handles formatting, ledger event, and confirmation.

Show this one-line hint to the user exactly once per session (track via the session-scoped reasoning; do not re-surface on every invocation):

> Routing through /thinkos-capture (same behavior, one fewer command to remember).

User message: $ARGUMENTS
