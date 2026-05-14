---
type: capture-source
source: calendar
schedule: daily-6am
status: stable
tags:
- continuous-capture
- calendar
- phase-c
permalink: think-os/continuous-capture/sources/calendar
---

# Continuous capture — Calendar

## What this captures

A daily snapshot of today's calendar events — written to a signal file for use by other agents and for personal reference. This is a lightweight data file, not a brief. It records what is on the calendar today: title, time, attendees, and meeting link.

This does NOT duplicate the morning brief. The morning brief (`01 Now/briefs/<date>-brief.md`) synthesizes the calendar snapshot alongside Current Focus and Tasks to produce narrative guidance. The calendar snapshot is the raw source data that the morning brief (and any other agent) can read. If the morning brief automation is also enabled, it reads this snapshot file rather than re-querying the Calendar MCP.

What does NOT count: declined events, all-day events with no description (holidays, OOO blocks), events from shared calendars the user has no involvement in (configurable — see filter below).

## Filter (what's worth capturing)

1. Events where the user's response status is `accepted` or `tentative`. Declined events are excluded.
2. Events from the primary calendar and any calendars the user explicitly subscribes to for work. Events from read-only shared calendars (e.g. holidays, team OOO calendars) are included only if they overlap with a working-hours window (8am–7pm local time) and have a non-empty description or attendee list.
3. All-day events with no description and no attendees are skipped (these are typically holidays or personal blocks that add no capture value).
4. Time range: today from midnight to 11:59pm local time.

The trigger does NOT attempt to prep for each meeting (no fetching agendas, no writing individual meeting-prep notes — that is the morning brief's job). It writes exactly one snapshot file per day.

## Schedule

- Cron (UTC): `0 11 * * *`
- Translated: "daily at 6am US Eastern (11am UTC)" — adjust the UTC offset for your timezone. For US Pacific, use `0 14 * * *`.
- Why this cadence: fires before the typical workday starts, so the snapshot is ready when the morning brief runs (also 6am) and when the user opens their first session.

Note: if you are not in US Eastern, edit the cron expression to match your local 6am in UTC. The setup command will prompt for timezone.

## Vault destination

`01 Now/Signals/calendar-<YYYY-MM-DD>.md`

One file per day. If the file already exists (e.g., the trigger re-fires due to a retry), the trigger overwrites it — today's snapshot is always current, not cumulative.

## Privacy routing

The following keywords in an event title or description trigger personal-hub-only routing for that event's entry within the snapshot:

`comp`, `salary`, `compensation`, `bonus`, `raise`, `offer letter`, `HR`, `performance review`, `PIP`, `health`, `medical`, `family`, `therapy`, `personal`

When a keyword matches for a specific event:
- That event's entry in the snapshot file is replaced with a redacted placeholder: `[event redacted — personal]`.
- The event's title is not written to the vault file or the ledger.
- The ledger entry for the overall snapshot gets `"redacted_events": N` counting how many events were redacted.

The snapshot file itself always lands in the active vault (it is a today-snapshot, not a sensitive note). Individual event content is what gets redacted.

## Trigger prompt

Register this verbatim via `CronCreate`:

```
You are the Think OS Calendar capture agent. Run daily.

Step 1 — Determine today's date in local time. Use the format YYYY-MM-DD.

Step 2 — Fetch today's events.
Call mcp__claude_ai_Google_Calendar__list_events with:
  - time_min: today at 00:00:00 local time (ISO 8601 with offset)
  - time_max: today at 23:59:59 local time (ISO 8601 with offset)
  - single_events: true
  - order_by: startTime

Step 3 — Filter events.
Exclude:
  - Events where the user's response status is "declined".
  - All-day events that have no description and no attendees.

For each remaining event, apply privacy check: scan the event summary (title) and description for these keywords (case-insensitive):
  comp, salary, compensation, bonus, raise, offer letter, HR, performance review, PIP, health, medical, family, therapy, personal
Set REDACT = true for events where any keyword matches.

Step 4 — Build the snapshot file.
Path: 01 Now/Signals/calendar-<YYYY-MM-DD>.md

File content:
  ---
  source: calendar
  date: <YYYY-MM-DD>
  event_count: <total events including redacted>
  captured_at: <ISO timestamp of now>
  ---

  # Calendar — <YYYY-MM-DD>

  For each event in chronological order:

  If REDACT == false:
    ## <HH:MM> — <event title>
    **Time:** <start time> – <end time> (or "all day")
    **Attendees:** <comma-separated display names, or "just me">
    **Link:** <meeting URL from conferenceData if present, else "none">
    **Description:** <first 300 chars of description, or omit if empty>

  If REDACT == true:
    ## [event redacted — personal]

  After all events:
  ---
  *Snapshot captured at <time>. <N> event(s) total, <M> redacted.*

Step 5 — Write via mcp__basic-memory__write_note to 01 Now/Signals/calendar-<YYYY-MM-DD>.md.
Use mode: overwrite (today's snapshot replaces any previous version from a retry).

Step 6 — Append one ledger event to ~/.thinkos/capture-log.jsonl:
  {
    "ts": "<ISO timestamp of now>",
    "source": "calendar",
    "detail": {
      "date": "<YYYY-MM-DD>",
      "event_count": <N>,
      "redacted_events": <M>
    },
    "output": "01 Now/Signals/calendar-<YYYY-MM-DD>.md",
    "mode": "overwrite",
    "bytes": <byte length of written content>
  }

Step 7 — Output one line: "Calendar snapshot written: <N> events for <YYYY-MM-DD> (<M> redacted)."
Do not output anything else.
```

## Ledger event shape

```json
{"ts":"2026-05-14T11:00:00Z","source":"calendar","detail":{"date":"2026-05-14","event_count":6,"redacted_events":0},"output":"01 Now/Signals/calendar-2026-05-14.md","mode":"overwrite","bytes":1843}
```

## How to enable

Run `/thinkos-capture-setup calendar` — or run `/thinkos-capture-setup` and select Calendar when prompted.

The setup command will ask for your timezone offset (to compute the correct UTC expression for your local 6am) before registering the trigger.

Prerequisites:
- Google Calendar MCP (`mcp__claude_ai_Google_Calendar__*`) must be connected. Run `claude mcp list` to verify.
- If the morning brief automation is also enabled, it should be set to run at or after 6am — it can then read the calendar snapshot rather than querying the Calendar MCP directly.

## How to disable

1. Run `/thinkos-automate list` to find `think-os-capture-calendar`.
2. Run `/thinkos-automate remove think-os-capture-calendar`.
3. Past snapshot files remain in the vault; future snapshots stop being written.
