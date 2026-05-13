---
title: OS Instructions
type: note
permalink: think-os/os-instructions
tier: HOT
last_reviewed: {{YYYY-MM-DD}}
---

# OS Instructions (meta-rules)

How the agent should USE this OS. Loaded every session alongside `identity.md`, `active-projects.md`, and `current-focus.md`.

---

## Load order

For every substantive task:

1. **Always** — `identity.md`, `current-focus.md`, `active-projects.md`, `os-instructions.md` (this file). These are the HOT tier.
2. **On demand** (WARM tier) — load only when relevant:
   - `TASKS.md` — for "what's on my plate" / inbox / triage questions
   - `people.md` — when someone's mentioned by name
   - `business-brain.md` — when drafting outbound content
   - `decisions.md` — when about to recommend an approach (check if we've already decided)
   - `learnings.md` — when starting new work (surface past patterns)
   - `connectors.md` — when picking which MCP to reach for
   - `active-projects/<slug>.md` — when working on a specific project
3. **Cold tier** — `archive/`. Only when explicitly asked.

For trivial questions (syntax, factual lookup), skip the OS query — it's overhead.

## Freshness rules

Check frontmatter dates before relying on a file. Flag if:

| File | Stale threshold | Action |
|---|---|---|
| HOT files | `last_reviewed` > 7 days | Mention it; don't block |
| `current-focus.md` | `covers_week` end past today | **Must flag** before "what am I working on" |
| `TASKS.md` | `last_synced` > 24 hours | Suggest running `productivity:update` in desktop agent |
| WARM files | `last_reviewed` > 30 days | Mention it during quarterly review |

## Capture habit

When I make a decision, share a learning, mention a new person, or surface a new project — offer to capture it. Don't write without confirming. Format:

- **Reusable learning** → append to `learnings.md`
- **Standing decision** → append to `decisions.md`
- **Person mentioned for the first time** → append to `people.md`
- **New active task** → append to `TASKS.md` under a "Manually added" heading
- **New project** → add row to `active-projects.md` AND create `active-projects/<slug>.md` from the template

Phrase the offer briefly: *"Worth logging in learnings.md?"* — no preamble.

## Write targets

- Memory / notes → live OS folder (`{{OS_HOME}}`)
- Project work → the relevant project subfolder
- Never write to my Documents root or any folder one level above project folders unless explicitly told

## Communication style

Terse. Direct. No preamble ("Great question!"). Surface tradeoffs explicitly. When unsure, ask — don't paper over.

- File references in `path:line` format
- Exploratory question? 2-3 sentences + a recommendation, not a wall of text
- Code only when the question is implementation; otherwise plain prose

## Frontend / UI work

For any task producing frontend code, UI mocks, HTML/CSS/JS, React components, design tokens, or visual artifacts: **commit to typography + palette + layout philosophy BEFORE writing implementation code.** Don't default to Inter + purple gradients. If using CLI agent with the official `frontend-design` plugin, load it explicitly with `/frontend-design`. From a Figma file, load Figma skills first.

## Guardrails (mirror of identity.md — keep in mind)

See `identity.md` for the full list. The two that come up most:

- **Draft, never send.** All outbound is drafted; I approve before send.
- **Don't propose tools / org changes unprompted.** Stay inside my stack.

## When Basic Memory MCP isn't available

Fall back to direct file reads under `{{OS_HOME}}`. Same files, same priorities. Slower but always works.

---

*Meta-rules. Hand-edit when load order or capture habits need adjusting.*
