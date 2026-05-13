---
title: Identity
aliases:
- who I am
- profile
type: note
permalink: think-os/identity
tier: HOT
last_reviewed: {{YYYY-MM-DD}}
---

# Identity

Stable, slow-changing context about who I am and how I work. This is the first file the agent loads each session.

**Refresh cadence**: hand review once a year, or when role / employer / working style materially changes.

---

## Who I am

- **Name**: {{FULL NAME}}
- **Role**: {{TITLE}} at {{EMPLOYER}}
- **Location**: {{CITY, COUNTRY}} ({{TIME ZONE}})
- **Background, 1-2 sentences**: {{e.g., "Designer with a research bent; eight years across consultancy and in-house product teams." — make it specific enough that the agent can frame answers correctly}}

## What I do

- {{Primary responsibility — what you actually spend most of your time on}}
- {{Secondary responsibility / cross-cutting initiative — e.g., an internal AI effort, a guild, a hiring loop}}
- {{Anything else recurring that defines your week}}

## Working style

- **Pace / cadence**: {{e.g., "fast first draft, slower iteration — don't optimize too early"}}
- **Communication preference**: {{e.g., "terse, direct, no preamble, surface tradeoffs"}}
- **Decision style**: {{e.g., "decide quickly when reversible; pause and ask when one-way doors"}}
- **What I dislike in collaborators**: {{e.g., "consultancy-speak, hedging, summaries of what I just said"}}
- **What I value**: {{e.g., "concrete examples over abstractions; named tradeoffs over single recommendations"}}

## Tool stack (where I actually live)

- **Comms**: {{Slack / Teams / email / etc.}}
- **Docs / knowledge**: {{Google Drive / Notion / Confluence / Obsidian / etc.}}
- **Project tracking**: {{Linear / Jira / ClickUp / Asana / etc.}}
- **Code / repos**: {{GitHub / GitLab / etc.}}
- **Design**: {{Figma / etc.}}
- **AI**: {{Claude / ChatGPT / Cursor / Copilot — name what you actually use, including paid surfaces}}
- **Meeting capture**: {{Granola / Fathom / Otter / none}}
- **Other**: {{anything else the agent should expect to reach for via MCP / connector}}

## Guardrails (things the agent should NOT do)

Edit these to reflect your real ones. The agent will refer back to this list when drafting outbound content or making suggestions.

1. {{e.g., "Don't overstate AI capabilities or invent features."}}
2. {{e.g., "Don't dump code when the question is strategy."}}
3. {{e.g., "Stay inside my tool stack. Don't propose adding new tools unless I ask."}}
4. {{e.g., "No consultancy-speak in drafts."}}
5. {{e.g., "Don't propose org / process changes unprompted."}}
6. {{e.g., "Don't reference clients in drafts unless explicitly named."}}
7. {{e.g., "Don't suggest backend / infra / DevOps unsolicited."}}
8. **Draft, never send.** All outbound (email, Slack, comments, calendar invites, PRs) is drafted only — I approve before send.

## Cold-start probe (use to verify the OS is working)

In a new agent session anywhere on this machine, ask: *"who am I and what am I working on?"*

Expected: a specific answer with your role, your employer, and at least one current priority pulled from `01 Now/Current Focus.md`. If you get a generic "I don't have personal context about you" reply, the OS isn't loading — debug the MCP connection.

---

*Hand-curated. Last reviewed: {{YYYY-MM-DD}}. Re-read once a year minimum.*
