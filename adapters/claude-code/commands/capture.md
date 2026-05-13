---
description: Capture a cross-project learning into learnings.md
permalink: think-os/adapters/claude-code/commands/capture
---

Append a structured learning entry to `learnings.md` via Basic Memory.

Take the user's message ($ARGUMENTS) and shape it into the standard format from `learnings.md`:

```markdown
### YYYY-MM-DD — <short title>
- **Context**: where this came up (project, conversation, meeting)
- **Learning**: the reusable insight, decision, or pattern
- **Applies to**: future engagement types where this is relevant
- **Tags**: #tag1 #tag2 #tag3
- **Source**: link to project file, Figma, doc, Slack thread, etc.
```

Use today's date. Extract title, context, learning, applies-to from $ARGUMENTS. Propose tags from the existing taxonomy in `learnings.md`. If the user's message is missing a section (e.g., no "applies to"), ask once for that specific piece before writing.

Then call `mcp__basic-memory__edit_note(identifier="Learnings", operation="append", content="<formatted entry>")`.

Confirm written.

User message: $ARGUMENTS
