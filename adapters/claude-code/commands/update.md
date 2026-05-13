---
description: Refresh Basic Memory's index from disk (CLI agent side)
permalink: think-os/adapters/claude-code/commands/update
---

Refresh Basic Memory's view of the personal context OS so any external edits (made in Obsidian, an editor, or by desktop agent's scheduled tasks) are picked up:

1. Run via Bash tool: `basic-memory reindex --project think-os`
2. After it completes, call the Basic Memory recent-activity tool to show what's changed in the last day
3. Show `01 Now/Tasks.md` staleness: read its `last_synced` frontmatter and report how stale it is

**Important boundary**: this command refreshes the INDEX. It does NOT pull fresh data from connectors (email / chat / project tracker). Those live in desktop agent. If `01 Now/Tasks.md` is stale, tell me to run `/productivity:update` in **desktop agent**, not here.

If you want a one-shot natural-language equivalent: "refresh basic-memory and show me what changed."
