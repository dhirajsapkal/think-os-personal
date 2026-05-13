---
description: Load deep context for a project by slug or name
permalink: think-os/adapters/claude-code/commands/project
---

Load the per-project deep file for the project named in arguments.

Try in order:
1. `mcp__basic-memory__read_note("02 Projects/$ARGUMENTS")` — direct slug match
2. If not found, `mcp__basic-memory__search_notes(query="$ARGUMENTS", page_size=3)` — fuzzy match
3. If still no hit, read `02 Projects/Project Index.md` and find the closest project name

Then summarize: status, path, stakeholders (with their roles), current state, open questions, next actions, recent decisions / learnings. Keep it scannable.

User arguments: $ARGUMENTS
