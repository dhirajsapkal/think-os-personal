---
title: Tasks
aliases:
- TASKS
- inbox
- plate
type: note
permalink: think-os/tasks
tier: WARM
last_synced: {{YYYY-MM-DD HH:MM}}
---

# Tasks

Connector-synced inbox: open items pulled from email, chat, project trackers, calendar, meeting transcripts. Refreshed by `/thinkos-refresh` (the connector-sweep command — works in any surface via the claude.ai bridge or native MCPs).

**Does NOT replace `01 Now/Current Focus.md`.** That's intent. This is inbox.

**Freshness rule**: if `last_synced` > 24 hours, suggest running `/thinkos-refresh`.

---

## How this file is organized

Each section is a source. Auto-generated entries note the source link. Manually added entries go in the dedicated section so they don't get overwritten on next sync.

- **Today** — today's working set; automation reads and writes this section by name
- **Manually added** — things I typed in, never overwritten by sync
- **Email** — flagged / unread threads needing response
- **Chat** — Slack / Teams threads where someone's waiting on me
- **Project tracker** — issues / tickets assigned to me or watched
- **Calendar** — upcoming meetings with prep required
- **Awaiting** — things I'm waiting on others for

---

## Today

<!-- Automation anchor: /thinkos-morning, /thinkos-plate, and /thinkos-refresh read and write exactly this section by its heading. Do not rename it. -->

- {{Today's working set — promoted from the sections below, plus anything added by hand}}

---

## Manually added

(Items I added by hand. Won't be overwritten by sync.)

- {{Item}} — {{date added}} — {{deadline if any}}

---

## Email

_Last synced: {{YYYY-MM-DD HH:MM}}_

- {{Thread subject}} — {{sender}} — {{action needed}} — [link]

---

## Chat

_Last synced: {{YYYY-MM-DD HH:MM}}_

- {{Channel / DM}} — {{topic}} — {{who's waiting}} — [link]

---

## Project tracker

_Last synced: {{YYYY-MM-DD HH:MM}}_

- {{Ticket ID}} — {{title}} — {{status}} — {{deadline}} — [link]

---

## Calendar (next 48h)

_Last synced: {{YYYY-MM-DD HH:MM}}_

- {{Date / time}} — {{meeting}} — {{prep needed if any}}

---

## Awaiting (I'm blocked on someone)

- {{What I need}} — from {{name}} — asked {{date}}

---

*Auto-refreshed by `/thinkos-refresh` (connector sweep). Manual edits to the "Manually added" section survive sync; edits elsewhere don't.*
