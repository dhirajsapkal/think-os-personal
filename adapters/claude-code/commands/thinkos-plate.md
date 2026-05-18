---
description: What's on your plate today (tasks + current focus)
permalink: think-os/adapters/claude-code/commands/thinkos-plate
---

Load:
- `mcp__basic-memory__read_note("Tasks")` — inbox
- `mcp__basic-memory__read_note("Current Focus")` — stated priorities

Apply the freshness rule from `90 System/OS Instructions.md`: if `01 Now/Tasks.md` `last_synced` is >24h old, flag it and offer to run `/thinkos-refresh` (the connector-sweep command — pulls from Gmail, Slack, Calendar, ClickUp, etc. via the claude.ai bridge or native MCPs, works in any surface).

Lead with stated priorities (intent), then surface inbox items grouped by source, then any "Awaiting" items I'm blocked on. Flag overdue.
