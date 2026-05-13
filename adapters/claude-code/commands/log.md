---
description: Append a manual entry to 01 Now/Work Log.md
permalink: think-os/adapters/claude-code/commands/log
---

Append a manual log entry to `01 Now/Work Log.md` via Basic Memory:

```
mcp__basic-memory__edit_note(
  identifier="Work Log",
  operation="append",
  content="\n## YYYY-MM-DD HH:MM — <project-or-context>\nSession: $ARGUMENTS\n"
)
```

Use:
- Today's date and current time
- The current working directory's project name as `<project-or-context>` if cwd is under a known project root, otherwise infer from $ARGUMENTS or use "CLI agent session"

Confirm the entry was appended. Don't write a summary preamble — keep the log entry verbatim from the user.

User message: $ARGUMENTS
