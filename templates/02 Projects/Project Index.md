---
title: Project Index
aliases:
- Active Projects
- active-projects
- projects
type: note
permalink: think-os/projects
tier: HOT
last_reviewed: {{YYYY-MM-DD}}
---

# Project Index

The map of every project I'm actively touching, pausing, monitoring, or recently completing. Each row is one project. Deep context lives beside this file as `02 Projects/<slug>.md`.

**Refresh cadence**: weekly during `/weekly-review`; quarterly hand audit.

**Status legend**: 🟢 active · 🟡 paused · 🔵 monitoring · ⚪ complete

---

## Index

| Slug | Name | Status | Path | One-liner |
|---|---|---|---|---|
| `{{slug-1}}` | {{Project Name}} | 🟢 | `~/{{path/to/folder}}` | {{What this is, one sentence}} |
| `{{slug-2}}` | {{Project Name}} | 🟢 | `~/{{path/to/folder}}` | {{What this is, one sentence}} |
| `{{slug-3}}` | {{Project Name}} | 🟡 | `~/{{path/to/folder}}` | {{Why it's paused, when to revisit}} |
| `{{slug-4}}` | {{Project Name}} | 🔵 | n/a | {{What I'm watching for}} |

## Conventions

- **Slug** is `kebab-case`, lowercase, no spaces. It's the filename of the deep file (`02 Projects/<slug>.md`).
- **Path** is where the project's files live on disk. Use `~/` notation; the agent will expand.
- **One-liner** is what the project IS — for the agent to disambiguate, not for me to read.
- New project? Add a row here AND create `02 Projects/<slug>.md` from `_Project Template.md`.
- Project finished? Mark ⚪ and leave the row for a quarter; drop after that during `/quarterly-review`.
- Project paused? Mark 🟡 and note the trigger to revisit in the deep file.

## Auto-update

A PostToolUse hook bumps a `.last-touched.json` file when I edit anything in a project directory — so the agent can tell what's hot vs. dormant without re-reading every deep file. Quarterly review reconciles status against `.last-touched.json`.

---

*This file is the source of truth for "what am I working on right now." Deep context lives in adjacent project notes.*
