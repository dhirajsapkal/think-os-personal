# Think OS Instructions For Claude Code

My personal context OS lives at `{{OS_HOME}}` and is accessible through the `basic-memory` MCP server.

## Always Available: Basic Memory MCP

Before answering anything substantive, use Basic Memory tools selectively:

- `mcp__basic-memory__search_notes("identity")` for role, working style, and guardrails
- `mcp__basic-memory__search_notes("active projects")` for the project index
- `mcp__basic-memory__search_notes("current focus")` for this week's priorities
- `mcp__basic-memory__search_notes("os instructions")` for meta-rules
- `mcp__basic-memory__read_note("TASKS")` for the connector-synced inbox
- `mcp__basic-memory__read_note("people")` for people / stakeholder context
- `mcp__basic-memory__search_notes("learnings " + topic)` for prior reusable patterns

Skip Think OS for trivial syntax, shell, or factual questions where personal/project context is irrelevant.

## Project Detection

If `cwd` is under a known project root, search for that project before answering substantively:

```text
active-projects/<project-slug>
```

## Freshness

Check frontmatter before relying on HOT files:

- `identity`, `active-projects`, `os-instructions` stale > 7 days: mention it
- `current-focus` past its `covers_week`: flag before answering "what am I working on?"
- `TASKS` last_synced > 24 hours: offer to refresh via the desktop agent / connector workflow

## Capture Habit

When I make a reusable decision or share a learning, offer:

```text
Worth logging in learnings.md? I can add it with tags [suggested].
```

If I confirm, append via Basic Memory `edit_note`.

Other capture targets:

- New person: `people.md`
- Standing decision: `decisions.md`
- New task: `TASKS.md`
- New project: `active-projects.md` plus `active-projects/<slug>.md`

## Write Targets

Default write targets:

- Memory / notes: `{{OS_HOME}}`
- Project work: relevant project subfolder

Never write above project folders unless explicitly told.

## Communication

Direct, concise, no preamble. Surface tradeoffs. Ask when unsure. Use `path:line` for file references.

Draft, never send outbound messages.

## Fallback

If Basic Memory MCP is unavailable, say so and fall back to direct file reads under `{{OS_HOME}}` if filesystem access is available.
