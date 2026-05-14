---
type: capture-source
source: linear
schedule: daily-6am
status: stable
tags:
- continuous-capture
- linear
- tickets
- phase-c
permalink: think-os/continuous-capture/sources/linear
---

# Continuous capture — Linear

## What this captures

Linear tickets assigned to the user that had a status change in the past 24 hours. This gives a daily pulse on what moved, what got stuck, and what landed in your queue overnight — without capturing every ticket comment or every ticket on the board.

What does NOT count: tickets assigned to others (even if you're a follower), tickets that changed only due to a field edit (title rename, label change) with no status transition, tickets in archived or completed cycles older than 7 days.

## Filter (what's worth capturing)

1. Tickets where `assignee == me` (resolved via `mcp__claude_ai_Atlassian__atlassianUserInfo` if Linear is accessed via the Atlassian MCP; or via the Linear-native MCP if connected).
2. `updatedAt` is within the past 25 hours (one-hour overlap for timezone edge cases).
3. The update must include a status/state change. If the API returns full ticket objects, compare `state.name` in the current snapshot against the previous day's ledger to determine whether state actually changed. If the API returns an activity feed, filter for `type: stateChange` events.
4. Skip tickets in `Cancelled` state where the cancellation happened more than 7 days ago — these are noise.

**MCP tool note**: Linear may be available via two paths in your environment:
- `mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql` — if your Linear workspace is connected via the Atlassian/Jira MCP bridge (some orgs route Linear through Jira sync).
- A direct Linear MCP if one is installed (check `claude mcp list` for a Linear entry).

The trigger prompt below uses the Atlassian MCP path (JQL query against the synced Linear board). If you have a direct Linear MCP installed, substitute its tool names. The `/thinkos-capture-setup linear` command will auto-detect which is available.

## Schedule

- Cron (local time): `0 6 * * *` — daily at 6am
- Translated: "every day at 6am local time"
- Why this cadence: a daily summary of ticket movement is the right granularity for a work-OS. Hourly would generate noise; more than 24 hours means you miss context during morning planning.
- **Laptop-wake note:** this job runs locally via launchd. If your Mac is asleep at 6am, launchd fires it on next wake. The 25-hour lookback window in the filter means tickets from a missed window are still captured on the next run.

## Vault destination

`01 Now/Signals/linear-<YYYY-MM-DD>.md`

Append-per-day: if the file already exists (e.g., a retry), overwrite it — today's full summary replaces partial output. One file per calendar day.

## Privacy routing

Linear ticket content is generally professional, not personal. However the following keywords in a ticket title or description trigger personal-hub-only routing for that ticket's entry:

`comp`, `salary`, `compensation`, `HR`, `performance review`, `PIP`, `health`, `personal`

When matched:
- That ticket's entry is replaced with `[ticket redacted — personal]` in the vault file.
- Title is omitted from the ledger; only `issue_id` is retained.
- Ledger entry gets `"redacted": true` at the event level if all tickets were redacted; otherwise `"redacted_tickets": N`.

In practice, Linear tickets matching these keywords are rare — they usually appear only in HR-adjacent tooling that happens to sync to Linear.

## Trigger prompt

This prompt is passed verbatim to `claude -p` by `scripts/thinkos-linear.sh`. Install the job via:

```bash
bash scripts/install-launchd-job.sh linear
```

This writes `~/Library/LaunchAgents/com.thinkos.linear.plist` (schedule: `0 6 * * *` local time) and loads it with `launchctl`.

```
You are the Think OS Linear capture agent. Run daily.

Step 1 — Determine today's date (YYYY-MM-DD) and the cutoff timestamp: now minus 25 hours (ISO 8601).

Step 2 — Resolve your Linear user identity.
Call mcp__claude_ai_Atlassian__atlassianUserInfo to get your account ID. If this fails (Linear not synced via Atlassian), check whether a direct Linear MCP is available and use it instead.

Step 3 — Fetch tickets assigned to me that changed in the past 25 hours.
Using the Atlassian MCP (Jira/Linear sync path):
  Call mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql with JQL:
    assignee = currentUser() AND updated >= "-25h" ORDER BY updated DESC
  Request fields: summary, status, priority, url, updated, project

  If a direct Linear MCP is available instead, use its equivalent "my issues updated since" query.

  Fetch up to 50 results. If more exist, note the count but don't paginate further (a daily snapshot doesn't need completeness beyond 50 state changes in 24h — that would indicate noise).

Step 4 — Filter for actual status changes.
For each returned ticket:
  a. Read the vault note "Capture Log" (at "90 System/Capture Log.md") via `mcp__basic-memory__read_note`. Scan lines starting with `{` as JSON. Find the most recent entry where source == "linear" and detail contains this issue_id. Extract the previous status value if present.
  b. If the current status differs from the previous status (or no previous entry exists), include this ticket.
  c. If status is identical to the last captured state, skip it.

Step 5 — Privacy check.
For each remaining ticket, scan summary (title) and description for:
  comp, salary, compensation, HR, performance review, PIP, health, personal
Set REDACT = true if any keyword matches.

Step 6 — Build the snapshot file.
Path: 01 Now/Signals/linear-<YYYY-MM-DD>.md

Content:
  ---
  source: linear
  date: <YYYY-MM-DD>
  ticket_count: <N>
  captured_at: <ISO timestamp>
  ---

  # Linear — <YYYY-MM-DD>

  For each ticket (REDACT == false):
  ## <status> — <summary>
  **ID:** <issue key>
  **Status:** <previous status if known> -> <current status>
  **Priority:** <priority>
  **Updated:** <ISO timestamp of last update>
  **Link:** <ticket URL>

  For each ticket (REDACT == true):
  ## [ticket redacted — personal]

  ---
  *<N> ticket(s) with status changes in the past 24 hours.*

Step 7 — Write via mcp__basic-memory__write_note to 01 Now/Signals/linear-<YYYY-MM-DD>.md (overwrite mode).

Step 8 — Append one ledger event per captured ticket to the vault note "Capture Log" (at "90 System/Capture Log.md") via `mcp__basic-memory__edit_note(identifier="Capture Log", operation="append", content="...")`:
  {
    "ts": "<ISO now>",
    "source": "linear",
    "detail": {
      "issue_id": "<id>",
      "title": "<summary>",
      "status": "<current status>",
      "previous_status": "<prior status or null>"
    },
    "output": "01 Now/Signals/linear-<YYYY-MM-DD>.md",
    "mode": "append",
    "bytes": <byte length of this ticket's section>
  }
  For redacted tickets, omit "title" from detail and add "redacted": true.

Step 9 — Output one line: "Linear snapshot written: <N> ticket(s) with status changes for <YYYY-MM-DD>."
```

## Ledger event shape

```json
{"ts":"2026-05-14T11:00:00Z","source":"linear","detail":{"issue_id":"ENG-1042","title":"Fix rate limiting on auth endpoint","status":"In Review","previous_status":"In Progress"},"output":"01 Now/Signals/linear-2026-05-14.md","mode":"append","bytes":312}
```

## How to enable

Run `/thinkos-capture-setup linear` — or run `/thinkos-capture-setup` and select Linear when prompted.

The command detects whether Linear is available via the Atlassian MCP or a direct Linear MCP, then installs the launchd job via `bash scripts/install-launchd-job.sh linear`.

Prerequisites:
- Either the Atlassian MCP (`mcp__claude_ai_Atlassian__*`) with Linear synced, or a direct Linear MCP connected. Run `claude mcp list` to verify.
- If neither is connected, skip this source until Linear integration is set up.

## How to disable

1. Run `/thinkos-automate remove linear` — this runs `launchctl unload ~/Library/LaunchAgents/com.thinkos.linear.plist` and deletes the plist.
2. Past snapshot files remain; future snapshots stop.
