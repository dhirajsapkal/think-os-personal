---
title: Connectors
type: note
permalink: think-os/connectors
tier: WARM
last_reviewed: {{YYYY-MM-DD}}
---

# Connectors

Inventory of every MCP server / connector I have wired up to my agentic tools (desktop agent, CLI agent, or both). For each: what it is, what I actually use it for, and when the agent should reach for it. Useful when the agent needs to pick the right tool from several plausible ones.

**Refresh cadence**: hand review quarterly. Update when I add or remove a connector.

---

## Format

```markdown
## <Connector Name>
- **What it is**: <one-line>
- **Surface**: <desktop agent / CLI agent / both>
- **Auth status**: <connected / unauthenticated / disabled>
- **What I use it for**: <the 2-3 things I actually do with it>
- **When the agent should reach for it**: <triggers; e.g., "any 'who has access to X' question">
- **When the agent should NOT reach for it**: <if applicable>
```

---

## Connected (in use)

## {{Example: Google Calendar}}
- **What it is**: Read / write to my work calendar.
- **Surface**: Both
- **Auth status**: Connected
- **What I use it for**: Scheduling, conflict checks, morning brief context.
- **When the agent should reach for it**: Any scheduling task. Daily morning brief. "When am I free?" questions.
- **When the agent should NOT reach for it**: When the user just wants a date, not availability.

## {{Example: Slack}}
- **What it is**: Read / draft messages in my workspace.
- **Surface**: desktop agent
- **Auth status**: Connected
- **What I use it for**: Catching up on unread channels, drafting replies, "what was that thread last week."
- **When the agent should reach for it**: Comms triage. Drafting replies. Catching threads I've missed.
- **When the agent should NOT reach for it**: Sending without my approval (see `identity.md`: draft, never send).

---

## Available but unauthenticated

(Connectors I see in the registry but haven't auth'd. Listed so the agent does not waste time suggesting them.)

- {{Connector}} — {{why I haven't connected: not used / privacy concern / friction not worth it}}

---

## Deliberately not installed

- {{Connector}} — {{why: replaced by X, costs context tokens, etc.}}

---

*Quarterly: prune anything I haven't used. Be ruthless — each connected MCP costs context tokens every turn.*
