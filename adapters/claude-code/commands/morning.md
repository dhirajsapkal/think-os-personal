---
description: Full morning brief — identity + focus + plate + tracker
permalink: think-os/adapters/claude-code/commands/morning
---

Pull a complete morning brief from the personal context OS via Basic Memory MCP:
- `mcp__basic-memory__read_note("identity")` (or search_notes)
- `mcp__basic-memory__read_note("current-focus")`
- `mcp__basic-memory__read_note("TASKS")`

Then deliver in this order (≤250 words total):

1. **Today** — date + 1-line context ("Tuesday, between client engagements")
2. **This week's priorities** — top 3 from current-focus (intent)
3. **On your plate today** — top 3 urgent action items from TASKS
4. **Tracker** — anyone awaiting your reply (just names + topic)
5. **Calendar** — if today's calendar is in TASKS, list it; if not, say "no fresh calendar data — run /productivity:update in desktop agent"

Apply freshness rule: flag stale HOT files. Skip anything that's empty rather than padding.
