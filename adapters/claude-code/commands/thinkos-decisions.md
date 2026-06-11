---
description: Search your standing decisions, optionally by topic
permalink: think-os/adapters/claude-code/commands/thinkos-decisions
---

Search `04 Knowledge/Decisions.md` for relevant standing decisions.

If arguments provided, filter: `mcp__basic-memory__search_notes(query="decisions $ARGUMENTS", page_size=3)`. Escalate on a miss: page=2, then page_size=10, then `read_note("Decisions")`. Snippets are pointers — read the matching entry in the note before quoting its content.
If no arguments, read the full `04 Knowledge/Decisions.md`: `mcp__basic-memory__read_note("Decisions")` (skip the re-read if it was already loaded this session).

**Superseded handling.** Entries follow the supersedes convention: a replacement decision carries `**Supersedes**: <date — old topic>`, and the replaced entry carries `**Superseded-by**: <date — new topic>`.

- **Default answers exclude superseded decisions.** Any entry with a `Superseded-by` line is stale — do not present it as a current rule. Answer from the superseding entry instead.
- When a superseded entry is the closest match to the query, say so and follow the chain: "That decision was superseded on <date> by <new topic> — here's the current rule."
- Show superseded entries in full only when the user asks for history ("what did we *used to* do", "show superseded decisions", `--all`).

Return matching entries with date, decision, why, applies to, and supersedes/superseded-by links where present.

User arguments: $ARGUMENTS
