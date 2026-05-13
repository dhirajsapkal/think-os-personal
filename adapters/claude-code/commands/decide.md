---
description: Capture a standing decision into decisions.md
permalink: think-os/adapters/claude-code/commands/decide
---

Append a structured decision entry to `decisions.md` via Basic Memory.

Take the user's message ($ARGUMENTS) and shape it into the standard format:

```markdown
## YYYY-MM-DD — <topic>
**Decision**: <what was decided>
**Why**: <reasoning at the time>
**Context**: <what prompted it>
**Applies to**: <project / general / specific tool>
**Supersedes**: <link to earlier decision if any>
```

Use today's date. Extract topic, decision, why, context, applies-to from $ARGUMENTS. If anything is unclear, ask ONCE for the most missing piece before writing.

Then call `mcp__basic-memory__edit_note(identifier="Standing Decisions", operation="append", content="<formatted entry>")`.

Per `decisions.md` convention, NEWER entries go above older ones — find the right insertion point or append after the format guide block.

Confirm written.

User message: $ARGUMENTS
