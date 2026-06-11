---
description: What's on your plate today (tasks + current focus)
permalink: think-os/adapters/claude-code/commands/thinkos-plate
---

Load:
- Tasks (inbox) — **section-scoped, never the full note** (~4k tokens). Deterministic read-only extraction of the `## Today` section (and `## This week` if present):

  ```bash
  awk '/^## (Today|This week)([[:space:]]|$)/{p=1; print; next} /^## /{p=0} p' "${THINKOS_HOME:-$HOME/ThinkOS/vault}/01 Now/Tasks.md"
  ```

  Fallback only if shell is unavailable or the anchors don't exist: `mcp__basic-memory__read_note("Tasks")`.
- `mcp__basic-memory__read_note("Current Focus")` — stated priorities; small HOT file, whole-file read is correct. Skip the re-read if it was already loaded this session.

Apply the freshness rule from `90 System/OS Instructions.md`: pull `last_synced` mechanically (`grep -m1 '^last_synced:' "${THINKOS_HOME:-$HOME/ThinkOS/vault}/01 Now/Tasks.md"`); if it is >24h old, flag it and offer to run `/thinkos-refresh` (the connector-sweep command — pulls from Gmail, Slack, Calendar, ClickUp, etc. via the claude.ai bridge or native MCPs, works in any surface).

Lead with stated priorities (intent), then surface inbox items grouped by source, then any "Awaiting" items I'm blocked on. Flag overdue.
