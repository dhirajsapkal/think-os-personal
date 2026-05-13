---
description: Walk OS frontmatter dates and report files past freshness thresholds
permalink: think-os/adapters/claude-code/commands/stale
---

Check freshness of all HOT / WARM tier files in the personal context OS per `90 System/OS Instructions.md` thresholds:

- HOT files (`05 Profile/Identity.md`, `02 Projects/Project Index.md`, `01 Now/Current Focus.md`, `90 System/OS Instructions.md`): `last_reviewed` > 7 days old → flag
- `01 Now/Current Focus.md`: `covers_week` end past today → flag (must roll over)
- `01 Now/Tasks.md`: `last_synced` > 24h → flag (suggest /productivity:update in desktop agent)
- WARM files (`03 People/People.md`, `04 Knowledge/Decisions.md`, `04 Knowledge/Learnings.md`, `90 System/Connectors.md`, `05 Profile/Business Brain.md`): `last_reviewed` > 30 days → flag

Method: use `mcp__basic-memory__list_directory` and `mcp__basic-memory__read_note` to inspect frontmatter dates, or read directly from the OS folder. Compare against today.

Report:
- ✅ Fresh files (count only)
- ⚠️ Stale files (name, days/hours since last reviewed, suggested refresh path)
- 🚨 Critical: `01 Now/Current Focus.md` past `covers_week` end → highest priority

If nothing is stale, say so in one line.
