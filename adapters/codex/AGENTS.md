# Think OS Instructions For Codex

Think OS is available through the `basic-memory` MCP server. The source-of-truth files live at `{{OS_HOME}}`.

Use Think OS selectively for substantive work involving my role, projects, people, decisions, priorities, or drafting in my voice. Skip it for trivial syntax, shell, or one-off coding questions.

Default lookups:

- `search_notes("identity")` for role, preferences, and guardrails
- `search_notes("project index active projects")` for the project index
- `search_notes("current focus")` for this week's priorities
- `search_notes("os instructions")` for OS usage rules
- `read_note("Tasks")` or `search_notes("tasks")` for the task inbox
- `read_note("People")` for colleagues / clients / stakeholders
- `search_notes("learnings " + topic)` for reusable prior patterns

When working inside a known project folder, search for the relevant `02 Projects/<slug>` note before making substantive recommendations.

For drafts written as me, load `Voice Profile` first.

Freshness:

- HOT files stale > 7 days: mention before relying on them
- `Current Focus` outside its `covers_week`: flag before answering priority questions
- `Tasks` last_synced > 24 hours: offer to refresh through the connector-enabled desktop workflow

Capture habit:

- Reusable learning: offer to append to `04 Knowledge/Learnings.md`
- Standing decision: offer to append to `04 Knowledge/Decisions.md`
- New person: offer to add/update `03 People/People.md`
- New task: offer to append to `01 Now/Tasks.md`
- New project: offer to update `02 Projects/Project Index.md` and create a project stub

Default write targets:

- Think OS memory / notes: `{{OS_HOME}}`
- Project work: relevant project subfolder

Never write above project folders unless explicitly told.

If Basic Memory MCP is unavailable, say so and fall back to direct file reads under `{{OS_HOME}}` if filesystem access is available.
