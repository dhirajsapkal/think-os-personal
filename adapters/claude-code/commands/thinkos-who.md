---
description: Show what you know about a specific person
permalink: think-os/adapters/claude-code/commands/thinkos-who
---

Search the personal context OS for the person named in arguments:

```
mcp__basic-memory__search_notes(query="$ARGUMENTS", page_size=5)
```

Return their canonical name (matching `03 People/People.md` heading), role, organization, current projects with this person, last touched, any "Avoid" flags. If multiple matches, show top 3 with confidence.

If no hit, say so explicitly and offer to add them via `mcp__basic-memory__edit_note(identifier="People", operation="append", ...)` if I want to capture.

User arguments: $ARGUMENTS
