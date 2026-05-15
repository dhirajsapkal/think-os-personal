---
description: Save substantive items from the current session to your vault (alias for /thinkos-capture --mode session-recap)
permalink: think-os/adapters/claude-code/commands/thinkos-save
---

**This command now delegates to `/thinkos-capture` with `--mode session-recap`. Result is identical; one fewer command to remember.**

Follow `adapters/claude-code/commands/thinkos-capture.md` with `$ARGUMENTS` treated as if the user had typed `/thinkos-capture --mode session-recap $ARGUMENTS`. The canonical playbook embeds the full session-recap flow (Step 0a silent triage, Step 0b topic-overlap dedup, per-draft chip-picker, reindex + report) verbatim — no behavior change from the v0.4.4 implementation.

Show this one-line hint to the user exactly once per session (track via the session-scoped reasoning; do not re-surface on every invocation):

> Routing through /thinkos-capture (same behavior, one fewer command to remember).

User message: $ARGUMENTS
