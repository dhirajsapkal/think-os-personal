---
description: What's on my plate today — 01 Now/Tasks.md + Current Focus
permalink: think-os/adapters/claude-code/commands/plate
---

Load:
- `mcp__basic-memory__read_note("Tasks")` — inbox
- `mcp__basic-memory__read_note("Current Focus")` — stated priorities

Apply the freshness rule from `90 System/OS Instructions.md`: if `01 Now/Tasks.md` `last_synced` is >24h old, flag it and tell me to run `/productivity:update` in desktop agent (that's where the connectors live; CLI agent can't do connector-sourced refresh).

Lead with stated priorities (intent), then surface inbox items grouped by source, then any "Awaiting" items I'm blocked on. Flag overdue.
