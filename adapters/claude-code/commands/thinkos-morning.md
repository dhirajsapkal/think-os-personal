---
description: Daily brief — focus, plate, recent log, calendar
permalink: think-os/adapters/claude-code/commands/thinkos-morning
---

Pull a complete morning brief from the personal context OS via Basic Memory MCP:
- `mcp__basic-memory__search_notes("identity")`
- `mcp__basic-memory__read_note("Current Focus")`
- `mcp__basic-memory__read_note("Tasks")`

Then deliver in this order (≤250 words total):

1. **Today** — date + 1-line context ("Tuesday, between client engagements")
2. **This week's priorities** — top 3 from Current Focus (intent)
3. **On your plate today** — top 3 urgent action items from Tasks
4. **Tracker** — anyone awaiting your reply (just names + topic)
5. **Calendar** — if today's calendar is in Tasks, list it; if not, before saying "no fresh calendar data", call `ToolSearch query="google calendar"` and if `mcp__claude_ai_Google_Calendar__list_events` is loadable, query today's events directly. Only fall back to the desktop-agent redirect if the tool is unavailable: "no fresh calendar data — run /productivity:update in desktop agent".
OR — if `claude mcp list` shows `claude.ai <Service>: ✓ Connected` for the connector you need, the agent can pull fresh data directly via `mcp__claude_ai_<Service>__*` tools without going to desktop agent. Check `70-claude-ai-bridge.md` for the protocol.

Apply freshness rule: flag stale HOT files. Skip anything that's empty rather than padding.
