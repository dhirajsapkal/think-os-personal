---
description: Daily brief — focus, plate, recent log, calendar
permalink: think-os/adapters/claude-code/commands/thinkos-morning
---

**No re-reads:** if identity / Current Focus were already loaded this session, do not re-issue those searches/reads — refer to context and load only what's missing.

Pull a complete morning brief from the personal context OS:
- `mcp__basic-memory__search_notes("identity", page_size=3)` — escalate on a miss (page=2 → page_size=10 → read_note of the best candidate)
- `mcp__basic-memory__read_note("Current Focus")` — small HOT file; whole-file read is correct
- Tasks — **section-scoped, never the full note** (~4k tokens). Deterministic read-only extraction of the `## Today` section (and `## This week` if present):

  ```bash
  awk '/^## (Today|This week)([[:space:]]|$)/{p=1; print; next} /^## /{p=0} p' "${THINKOS_HOME:-$HOME/ThinkOS/vault}/01 Now/Tasks.md"
  ```

  Fallback only if shell is unavailable or the anchors don't exist in the file: `mcp__basic-memory__read_note("Tasks")`.

Then deliver in this order (≤250 words total):

1. **Today** — date + 1-line context ("Tuesday, between client engagements")
2. **This week's priorities** — top 3 from Current Focus (intent)
3. **On your plate today** — top 3 urgent action items from Tasks
4. **Tracker** — anyone awaiting your reply (just names + topic)
5. **Calendar** — if today's calendar is in Tasks, list it; if not, before saying "no fresh calendar data", call `ToolSearch query="google calendar"` and if `mcp__claude_ai_Google_Calendar__list_events` is loadable, query today's events directly. If the calendar connector is unavailable on this surface, suggest `/thinkos-refresh --source calendar` (or full `/thinkos-refresh`) once a connector path is available.

Apply freshness rule: flag stale HOT files. Skip anything that's empty rather than padding.
