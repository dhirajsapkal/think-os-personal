---
title: People
aliases:
- personal CRM
- stakeholders
type: note
permalink: think-os/people
tier: WARM
last_reviewed: {{YYYY-MM-DD}}
---
<!-- thinkos:stub -->

# People

Mini personal CRM. Colleagues, clients, stakeholders, useful contacts. Used when the agent needs to know who someone is — their role, our shared projects, how we work together, anything I want to remember.

**Append via `/thinkos-who`** when a new person comes up, or by hand.

---

## Format

```markdown
## <Canonical Name>
- **Aliases**: <nicknames, Slack handles, email prefixes — anything I call them>
- **Role**: <title, team>
- **Organization**: <employer, or "external" / "client at X">
- **Working relationship**: <how I know them, frequency, channel>
- **Current projects**: <which project slugs we share>
- **Communication style**: <how they like to be reached, what works, what doesn't>
- **Last touched**: <YYYY-MM-DD, what about>
- **Notes**: <anything useful — preferences, sensitivities, context>
- **Avoid**: <topics or framings that don't land well, if any>
```

**The `aliases:` convention** — one person, one entry. When a nickname or handle comes up ("AC said...", "@alexc pinged me"), match it against `Aliases` lines before creating a new entry. Cheap manual entity resolution: the agent adds newly observed nicknames/handles here instead of spawning duplicates.

---

## People (alphabetical by first name or canonical handle)

## {{Example: Alex Chen}}
- **Aliases**: {{e.g., "AC", "@alexc", "alex.chen@"}}
- **Role**: {{e.g., Product Manager, Platform team}}
- **Organization**: {{Same Org / Client X / external}}
- **Working relationship**: {{e.g., "Weekly sync on the X engagement since March; mostly Slack DM"}}
- **Current projects**: `{{slug}}`, `{{slug}}`
- **Communication style**: {{e.g., "Prefers short Slack threads over email; doesn't love async docs"}}
- **Last touched**: {{YYYY-MM-DD — what}}
- **Notes**: {{useful detail}}
- **Avoid**: {{optional}}

---

*Append-as-mentioned. Quarterly review prunes anyone I haven't touched in 6 months unless they're flagged "keep."*
