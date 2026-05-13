---
description: Search reusable learnings by topic or tag
permalink: think-os/adapters/claude-code/commands/thinkos-learnings
---

Search `04 Knowledge/Learnings.md` for reusable patterns relevant to the topic.

`mcp__basic-memory__search_notes(query="learnings $ARGUMENTS", page_size=10)` — supports topics ("design system kickoff") or tags ("#facilitation #workshop").

Return matching entries with date, title, learning, applies-to, source. Order by relevance. If nothing matches, suggest tags from the taxonomy in `04 Knowledge/Learnings.md` that might fit better.

User arguments: $ARGUMENTS
