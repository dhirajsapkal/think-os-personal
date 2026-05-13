---
description: Search your standing decisions, optionally by topic
permalink: think-os/adapters/claude-code/commands/thinkos-decisions
---

Search `04 Knowledge/Decisions.md` for relevant standing decisions.

If arguments provided, filter: `mcp__basic-memory__search_notes(query="decisions $ARGUMENTS")`.
If no arguments, read the full `04 Knowledge/Decisions.md`: `mcp__basic-memory__read_note("Standing Decisions")`.

Return matching entries with date, decision, why, applies to. Flag any that have been superseded.

User arguments: $ARGUMENTS
