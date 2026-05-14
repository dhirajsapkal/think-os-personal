---
type: capture-source
source: granola
schedule: hourly
status: stable
tags:
- continuous-capture
- granola
- meetings
- phase-c
permalink: think-os/continuous-capture/sources/granola
---

# Continuous capture — Granola

## What this captures

Every meeting transcript that Granola records, as soon as it is available. This covers any meeting Granola was running for — internal syncs, external calls, 1:1s, demos. Each meeting gets its own vault file. The hourly trigger checks for new transcripts since the last run and writes only the ones not yet captured. Meetings that have no transcript yet (still in progress or not yet processed) are skipped and picked up on the next hourly fire.

What does NOT count: folders, meeting stubs with no transcript content, meetings explicitly deleted in Granola before capture runs.

## Filter (what's worth capturing)

1. Meeting must have a transcript (non-empty body from `mcp__claude_ai_Granola__get_meeting_transcript`).
2. Meeting `start_time` must be within the past 25 hours (catches the hourly window plus a one-hour overlap for late-processing transcripts).
3. Deduplicate against the vault note "Capture Log" (`90 System/Capture Log.md`): if an entry with `source: granola` and `detail.meeting_id` matching this meeting already exists, skip it.
4. No minimum length filter — even short check-ins are worth capturing; size is cheap.

The one-hour overlap in rule 2 handles cases where Granola finishes processing a transcript after the previous hourly window closed.

## Schedule

- Cron (local time): `0 * * * *`
- Translated: "every hour, on the hour"
- Why this cadence: meetings are short-lived signals; capturing within an hour keeps the vault current for same-day context queries and avoids the vault falling 24+ hours behind during heavy meeting days.
- **Laptop-wake note:** this job runs locally via launchd. If your Mac is asleep, the job does not fire. Missed hourly windows are not retried — transcripts from a sleep window are picked up on the next run that wakes (via the 25-hour lookback window in the filter).

## Vault destination

`04 Knowledge/Meetings/<YYYY-MM-DD>-<slug>.md`

Where `<slug>` is the meeting title lowercased, spaces replaced with hyphens, non-alphanumeric characters stripped, truncated to 60 characters. Example: `04 Knowledge/Meetings/2026-05-14-product-sync.md`.

If a file at that path already exists, append a `-2`, `-3` suffix rather than overwriting. (In practice this shouldn't happen given the dedup filter, but defensive handling is safer.)

## Privacy routing

The following keywords in the meeting title or transcript trigger personal-hub-only routing:

`comp`, `salary`, `compensation`, `bonus`, `raise`, `offer letter`, `HR`, `performance review`, `PIP`, `health`, `medical`, `family`, `1:1`, `one-on-one`, `personal`

When any keyword matches (case-insensitive):
- Vault destination changes to personal hub regardless of active vault.
- Ledger entry gets `"redacted": true`.
- Ledger `detail` field includes only `meeting_id` and `title` — transcript content is omitted from the ledger entirely. It still writes to the vault file.

The trigger prompt includes this check before every write.

## Trigger prompt

The prompt body lives at `scripts/cron-prompts/granola.txt`. The generic dispatcher `scripts/thinkos-cron-run.sh granola` reads it and pipes it to `claude -p`. Install the job via:

```bash
bash scripts/install-launchd-job.sh granola
```

This writes `~/Library/LaunchAgents/com.thinkos.granola.plist` (schedule: `0 * * * *`) and loads it with `launchctl`.

```
You are the Think OS Granola capture agent. Run on this prompt hourly.

Step 1 — Load last-capture cursor.
Read the vault note "Capture Log" (at "90 System/Capture Log.md") via `mcp__basic-memory__read_note`. Scan lines starting with `{` as JSON. Find the most recent entry where source == "granola". Record its ts value as LAST_CAPTURE. If no such entry exists, use a timestamp 25 hours ago.

Step 2 — List recent meetings.
Call mcp__claude_ai_Granola__list_meetings with no filter. From the result, select meetings where start_time is after (LAST_CAPTURE minus 1 hour) to catch any late-processing transcripts. If the result is paginated, fetch all pages.

Step 3 — Deduplicate.
For each candidate meeting, check the vault note "Capture Log" (`90 System/Capture Log.md`) for an existing entry with source == "granola" and detail.meeting_id == this meeting's id. Skip any that already have a ledger entry.

Step 4 — Fetch and write each new meeting.
For each meeting that passes dedup:

  a. Call mcp__claude_ai_Granola__get_meeting_transcript with the meeting id.
     If the transcript body is empty or null, skip this meeting (not yet processed).

  b. Privacy check: scan the meeting title and transcript body for any of these keywords (case-insensitive):
     comp, salary, compensation, bonus, raise, offer letter, HR, performance review, PIP, health, medical, family, 1:1, one-on-one, personal
     Set PERSONAL = true if any keyword matches, false otherwise.

  c. Build the vault path:
     - date: meeting start_time formatted as YYYY-MM-DD
     - slug: title lowercased, spaces to hyphens, non-alphanumeric stripped, truncated to 60 chars
     - path: 04 Knowledge/Meetings/<date>-<slug>.md
     If PERSONAL == true, route to personal hub vault instead (same relative path).

  d. Build the vault file content in this format:
     ---
     source: granola
     meeting_id: <id>
     title: <title>
     date: <YYYY-MM-DD>
     attendees: <comma-separated attendee names if available>
     granola_url: <url if available in the meeting object>
     captured_at: <ISO timestamp of now>
     personal: <true|false>
     ---

     # <title>

     **Date:** <YYYY-MM-DD>
     **Attendees:** <names or "not listed">
     **Granola link:** <url or "not available">

     ## Transcript

     <full transcript body, verbatim>

  e. Write via mcp__basic-memory__write_note to the computed path. If the path already exists, append -2 to the slug and retry once.

  f. Append one ledger event to the vault note "Capture Log" (at "90 System/Capture Log.md") via `mcp__basic-memory__edit_note(identifier="Capture Log", operation="append", content="...")`:
     {
       "ts": "<ISO timestamp of now>",
       "source": "granola",
       "detail": {
         "meeting_id": "<id>",
         "title": "<title>"
       },
       "output": "<vault path written>",
       "mode": "create",
       "bytes": <byte length of written content>,
       "redacted": <true if PERSONAL, omit if false>
     }

Step 5 — If zero new meetings were found and written, exit silently (no output).
If one or more were written, output a single line: "Captured N Granola meeting(s): <titles joined by comma>."
Do not output anything else.
```

## Ledger event shape

```json
{"ts":"2026-05-14T15:00:00Z","source":"granola","detail":{"meeting_id":"abc123","title":"Product sync"},"output":"04 Knowledge/Meetings/2026-05-14-product-sync.md","mode":"create","bytes":4821}
```

Privacy-routed variant (personal keyword matched):

```json
{"ts":"2026-05-14T15:00:00Z","source":"granola","detail":{"meeting_id":"def456","title":"1:1 with manager"},"output":"04 Knowledge/Meetings/2026-05-14-1-1-with-manager.md","mode":"create","bytes":3102,"redacted":true}
```

## How to enable

Run `/thinkos-capture-setup granola` — or run `/thinkos-capture-setup` and select Granola when prompted.

The command installs the launchd job via `bash scripts/install-launchd-job.sh granola`.

Prerequisites:
- Granola MCP (`mcp__claude_ai_Granola__*`) must be connected and authenticated. Run `claude mcp list` to verify. If not present, install via the Granola plugin and re-authenticate.
- The vault note "Capture Log" at `90 System/Capture Log.md` must exist (Phase B creates it). If missing, create it via `mcp__basic-memory__write_note(path="90 System/Capture Log.md", content="# Capture Log\n")` before enabling this source.

## How to disable

1. Run `/thinkos-automate remove granola` — this runs `launchctl unload ~/Library/LaunchAgents/com.thinkos.granola.plist` and deletes the plist.
2. The job stops firing. Existing vault files and ledger entries are not deleted.
