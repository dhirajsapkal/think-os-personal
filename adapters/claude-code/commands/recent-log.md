---
description: What did I do recently? Summarize last N days of work-log entries
permalink: think-os/adapters/claude-code/commands/recent-log
---

Summarize recent work-log entries. Defaults to the last 7 days; pass `--days N` to change the window.

## Step 1 — Parse arguments

Extract `--days N` from `$ARGUMENTS` if present. Default to 7 if omitted.

## Step 2 — Read the work log

```text
mcp__basic-memory__read_note(identifier="01 Now/Work Log")
```

If Basic Memory MCP is unavailable, read the file directly from `$OS_HOME/01 Now/Work Log.md`.

## Step 3 — Filter to the requested window

From the log, extract all entries whose date falls within the last N days from today. Work-log entries are expected to have date headers in ISO format (`YYYY-MM-DD`) or similar.

If fewer than 3 entries are found, note: "Only <count> entries in the last N days — log may be sparse. Run `/thinkos-doctor` to check capture health."

## Step 4 — Summarize

Present:

1. **By-day list** — one bullet per day with a short summary of what was logged.
2. **Themes** — 2–4 recurring topics or projects that appeared across entries.
3. **Notable decisions or learnings** — anything that looks like a reusable insight (flag with "Worth logging?").

Keep the summary tight. Do not reproduce the raw log verbatim — that wastes tokens and buries the signal.

## Step 5 — Offer to drill into a day (interactive)

After the summary, offer: "Want to see the full entry for any specific day?"

If the user picks a day, show the raw entry for that date only.

## Flags reference

| Flag | Effect |
|------|--------|
| `--days N` | Look back N days instead of 7 |
| `--raw` | Dump the raw log lines without summarising |

## Example invocations

- `/recent-log` — last 7 days
- `/recent-log --days 14` — last two weeks
- `/recent-log --raw` — unprocessed log dump

User message: $ARGUMENTS
