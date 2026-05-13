---
title: Work Log
type: note
permalink: think-os/work-log
tier: WARM
---

# Work Log

Append-only chronological log of what I worked on. Auto-captured by the CLI agent Stop hook at session end. Manual entries via `/log "<message>"`.

Used for:
- Weekly review (`/weekly-review` reads the last 7 days)
- "What did we do last session?" continuity
- Quarterly review and archive rotation

**Rotation**: at the start of each quarter, `/quarterly-review` moves this file to `archive/work-log-YYYY-Qn.md` and starts a fresh one.

---

## Auto-capture format

```
## YYYY-MM-DD HH:MM — <project-or-context>
Session: <one-line summary of what happened>
Outcome: <what changed — files written, decisions made, blockers found>
Files: <comma-separated list of files touched>
Session-id: <CLI agent session id>
```

## Manual entry format (via `/log`)

```
## YYYY-MM-DD HH:MM — <project-or-context>
<freeform single-paragraph note — what I learned, what I decided, what I want to remember>
```

---

## Entries (newest first)

<!-- Entries will be appended here by the Stop hook and /log. Leave the section heading. -->
