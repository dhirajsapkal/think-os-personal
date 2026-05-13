---
description: Search standing decisions, optionally filtered by topic
permalink: think-os/adapters/claude-code/commands/decisions
---

Search `decisions.md` for relevant standing decisions.

If arguments provided, filter: `mcp__basic-memory__search_notes(query="decisions $ARGUMENTS")`.
If no arguments, read the full `decisions.md`: `mcp__basic-memory__read_note("decisions")`.

Return matching entries with date, decision, why, applies to. Flag any that have been superseded.

User arguments: $ARGUMENTS
