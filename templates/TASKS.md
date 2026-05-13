---
title: TASKS
type: note
permalink: think-os/tasks
tier: WARM
last_synced: {{YYYY-MM-DD HH:MM}}
---

# TASKS

Connector-synced inbox: open items pulled from email, chat, project trackers, calendar. Refreshed by the `productivity:update` skill in desktop agent (it queries the connectors and rewrites this file).

**Does NOT replace `current-focus.md`.** That's intent. This is inbox.

**Freshness rule**: if `last_synced` > 24 hours, suggest running `productivity:update`.

---

## How this file is organized

Each section is a source. Auto-generated entries note the source link. Manually added entries go in the dedicated section so they don't get overwritten on next sync.

- **Manually added** — things I typed in, never overwritten by sync
- **Email** — flagged / unread threads needing response
- **Chat** — Slack / Teams threads where someone's waiting on me
- **Project tracker** — issues / tickets assigned to me or watched
- **Calendar** — upcoming meetings with prep required
- **Awaiting** — things I'm waiting on others for

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

*Auto-refreshed by `productivity:update` in desktop agent. Manual edits to the "Manually added" section survive sync; edits elsewhere don't.*
