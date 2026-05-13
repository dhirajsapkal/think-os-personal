---
title: Home
type: dashboard
permalink: think-os/home
tier: HOT
last_reviewed: {{YYYY-MM-DD}}
---

# Think OS Home

This is the front door for your personal context OS. Open this first in Obsidian when you want to orient, update context, or check what the agent should know.

## Start Here

Fill these first:

1. `05 Profile/Identity.md` — who you are, how you work, hard guardrails
2. `01 Now/Current Focus.md` — what matters this week
3. `02 Projects/Project Index.md` — the map of active, paused, and monitoring projects

Then run the cold-start probe from a fresh agent session:

```text
who am I and what am I working on?
```

## Daily Places

- `01 Now/Current Focus.md` — stated priorities for the week
- `01 Now/Tasks.md` — connector-synced inbox and manually added tasks
- `02 Projects/Project Index.md` — project map and folder paths
- `03 People/People.md` — useful context about collaborators and stakeholders

## Vault Map

| Area | What goes here | When to open it |
|---|---|---|
| `01 Now/` | Current focus, task inbox, work log | Daily or weekly review |
| `02 Projects/` | Project index and one note per project | Starting or resuming project work |
| `03 People/` | Lightweight personal CRM | Before meetings, drafts, or stakeholder questions |
| `04 Knowledge/` | Decisions and reusable learnings | Before recommending an approach |
| `05 Profile/` | Identity, voice, business context | Annual review, voice tuning, onboarding |
| `90 System/` | Agent instructions and connector map | Setup, debugging, changing rules |
| `99 Archive/` | Rotated logs and dormant project notes | Only when looking backward |

## What Agents Should Load

Agents should use `90 System/OS Instructions.md` for load order and capture rules. The short version:

- Always load the HOT tier for substantive work.
- Load WARM notes only when relevant.
- Capture decisions, learnings, people, tasks, and new projects only after confirmation.

---

*Keep this page short. If it stops feeling like a front door, move detail into the relevant folder.*
