---
description: Walk OS frontmatter dates and report files past freshness thresholds
permalink: think-os/adapters/claude-code/commands/stale
---

Check freshness of all HOT / WARM tier files in the personal context OS per `os-instructions.md` thresholds:

- HOT files (`identity.md`, `active-projects.md`, `current-focus.md`, `os-instructions.md`): `last_reviewed` > 7 days old → flag
- `current-focus.md`: `covers_week` end past today → flag (must roll over)
- `TASKS.md`: `last_synced` > 24h → flag (suggest /productivity:update in desktop agent)
- WARM files (`people.md`, `decisions.md`, `learnings.md`, `connectors.md`, `business-brain.md`): `last_reviewed` > 30 days → flag

Method: use `mcp__basic-memory__list_directory` and `mcp__basic-memory__read_note` to inspect frontmatter dates, or read directly from the OS folder. Compare against today.

Report:
- ✅ Fresh files (count only)
- ⚠️ Stale files (name, days/hours since last reviewed, suggested refresh path)
- 🚨 Critical: `current-focus.md` past `covers_week` end → highest priority

If nothing is stale, say so in one line.
